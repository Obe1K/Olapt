# -*- coding: utf-8 -*-
"""Симулятор Акта 1 «Империи слов».

Правила — из вкладки «Правила Акта 1»; все числа баланса собраны в P.
Бот играет за Маску: захватывает поселения по порядку, ставит обелиски,
берёт марионеток под контроль. Ученики отличаются только тем, в какие дни
они занимаются.

    python3 Tools/game/act1_sim.py --runs 300
    python3 Tools/game/act1_sim.py --runs 300 --json /tmp/out.json
"""
import argparse
import json
import math
import random
import statistics

P = dict(
    days=90,
    accuracy=0.85,          # доля верных ответов
    avra_per_correct=1.5,   # средняя Авра за верный ответ в бою и на вылазке
    plan_avra=150,          # день, когда пройден план «Сегодня», вместе с +20 за весь план
    extra_avra=0,           # тренировки сверх плана
    assault_cost=15,        # Авра за каждую марионетку в бою
    bind_cost=10,           # взять марионетку под контроль
    take_share=0.5,         # из поселения можно забрать в войско не больше этой доли исходных жителей
    sortie_cost=15,
    agent_feed=3,
    max_agents=10,
    obelisk_cost=200, obelisk_restore=100,
    decree_cost=(150, 250, 400),
    decree_days=(20, 40, 60),   # когда ежедневный ученик осваивает грамматику ступени
    charge_up=20, charge_down=25,
    wake_low=0.08, wake_zero=0.15,
    lose_share=0.5,
    grace=7,
    body_days=3, captive_days=7,
    alert_decay=5, alert_flee=2, alert_abduct=5, alert_key=25, alert_exposed=15, alert_failed_sortie=10,
    reinforce_at=50, patrol_at=100,
    expose_per_cultist=0.01,
    boss_questions=20, boss_pass=13, boss_avra=50,
    patrol_pass=7,
    zone_discount=0.75, out_of_zone=1.5,
    # (порог итога, исход, доли жителей: гибнут, бегут; потери отряда — доля силы обороны)
    assault_table=((7, 'fail', 0, 0, None), (12, 'hard', 0.30, 0.30, 1.0),
                   (17, 'sure', 0.20, 0.15, 0.5), (99, 'rout', 0.10, 0.05, 0.25)),
    ratio_bonus=((1.0, -4), (1.5, 0), (2.0, 2), (3.0, 4), (5.0, 6), (1e9, 10)),
    # (порог итога, сколько увели); провал — никто не вернулся
    sortie_table=((5, -1), (10, 0), (15, 1), (19, 2), (99, 3)),
    key_need=15,
    guard_pen_cap=5,        # потолок штрафа вылазки за стражу (−1 за каждых 2 стражников)
    start_army=20,
    regarrison=0.5,         # какую долю стражи феодал возвращает в потерянное Маской поселение
    cemetery_per_day=2,
    army_wake_factor=0.5,   # марионетки в войске просыпаются медленнее кукол в поселениях     # кладбище Молчаливой деревни: столько марионеток в день можно поднять всегда
    sortie_min_free=5,      # не уводить людей из почти пустого поселения
)

TOWNS = [
    # i, имя, жителей, стража, укрепления, культисты, вера, босс
    (0, 'Молчаливая деревня', 20, 0, 1.0, 0, 0, None),
    (1, 'Деревня сетей', 60, 2, 1.0, 2, 1, 'pop'),
    (2, 'Пшеничная долина', 80, 5, 1.25, 6, 2, 'captain'),
    (3, 'Тенистая роща', 100, 6, 1.5, 10, 3, 'crimson'),
    (4, 'Сумрачный холм', 140, 24, 3.0, 6, 2, 'lord'),
]
ROADS = {0: [1], 1: [0, 2], 2: [1, 3, 4], 3: [2, 4], 4: [2, 3]}
DEVOUT = (0.0, 0.10, 0.33, 0.55)
NO_ABDUCT = {'crimson', 'lord'}       # этих боссов не похитить: поселение берут только штурмом

PROFILES = {
    'daily': lambda d: True,
    'weekends': lambda d: d % 7 not in (5, 6),
    'away_week': lambda d: not (30 <= d <= 36),
    'quit_2w': lambda d: not (40 <= d <= 53),
}
DECREE_PACE = {'daily': 1.0, 'weekends': 1.4, 'away_week': 1.1, 'quit_2w': 1.2}


def binom(rng, n, p):
    return sum(1 for _ in range(int(n)) if rng.random() < p)


class Town:
    def __init__(self, row):
        (self.i, self.name, self.pop, self.base_guards, self.walls,
         self.cultists, self.faith, self.boss) = row
        self.base_pop = self.pop
        self.base_cultists = self.cultists
        self.orig_guards = self.base_guards
        self.owner = 'mask' if self.i == 0 else 'lord'
        self.dolls = self.pop if self.i == 0 else 0
        self.alert = 0.0
        self.obelisk = 'lit' if self.i == 0 else None     # башня — первый обелиск
        self.charge = 100.0
        self.grace = 0
        self.agents = 0
        self.key_agents = 0
        self.unfed = 0
        self.captain_taken = False
        self.pop_taken = False
        self.boss_taken = False
        self.garrison = 0
        self.taken_to_army = 0

    def guards(self):
        g = self.base_guards * (1.5 if self.alert >= P['reinforce_at'] else 1.0)
        return g / 2 if self.captain_taken else g

    def defense(self):
        return (self.guards() * 3 + self.cultists) * self.walls


class Sim:
    def __init__(self, profile, seed):
        self.rng = random.Random(seed)
        self.profile = profile
        self.active = PROFILES[profile]
        self.t = [Town(r) for r in TOWNS]
        self.avra = 0.0
        self.army = P['start_army']
        self.captives = []     # день, до которого ждёт
        self.bodies = []
        self.decrees = 0
        self.cemetery = 0
        self.day = 0
        self.done = None
        self.first_capture = {}
        self.losses = 0
        self.log = []
        self.spent = dict(assault=0, bind=0, sortie=0, agents=0, obelisk=0, decree=0)
        self.owned_series = []
        self.army_series = []
        self.avra_series = []

    # ---------- справочное ----------
    def owned(self, include0=False):
        return [x for x in self.t if x.owner == 'mask' and (include0 or x.i != 0)]

    def covering(self, town):
        best = None
        for o in self.t:
            if o.obelisk != 'lit' or o.owner != 'mask':
                continue
            if o.i == town.i or town.i in ROADS[o.i]:
                best = o.charge if best is None else max(best, o.charge)
        return best

    def mult(self, town):
        if self.covering(town) is not None:
            return P['zone_discount']
        return P['out_of_zone']

    def ok(self, n):
        return sum(1 for _ in range(n) if self.rng.random() < P['accuracy'])

    def note(self, text):
        self.log.append((self.day, text))

    def pay(self, kind, amount):
        self.avra -= amount
        self.spent[kind] += amount

    # ---------- день ----------
    def step(self):
        d = self.day
        active = self.active(d)
        if active:
            self.avra += (P['plan_avra'] + P['extra_avra']) * P['accuracy'] / 0.85
        for o in self.t:
            if o.obelisk == 'lit':
                o.charge = min(100.0, o.charge + P['charge_up']) if active else max(0.0, o.charge - P['charge_down'])
        self.cemetery = P['cemetery_per_day']
        self.bodies = [x for x in self.bodies if x >= d]
        self.captives = [x for x in self.captives if x >= d]
        self.wake()
        self.cultists_act()
        self.check_lost()
        self.infiltration()
        self.alerts(active)
        if active:
            self.bot()      # и после финала бот держит и отбивает земли
        self.owned_series.append(len(self.owned()))
        self.army_series.append(self.army)
        self.avra_series.append(round(self.avra))
        self.day += 1

    def rate_for(self, charge):
        if charge is None or charge <= 0:
            return P['wake_zero']
        return P['wake_low'] if charge < 50 else 0.0

    def wake(self):
        for town in self.owned():
            if town.grace > 0:
                town.grace -= 1
                continue
            rate = self.rate_for(self.covering(town))
            if rate:
                town.dolls -= binom(self.rng, town.dolls, rate)
        tower = self.t[0]
        rate = self.rate_for(tower.charge if tower.obelisk == 'lit' else None) * P['army_wake_factor']
        if rate:
            self.army -= binom(self.rng, self.army, rate)

    def cultists_act(self):
        iron = 2 if self.decrees >= 2 else 1
        for town in self.owned():
            if town.cultists:
                town.dolls = max(0, town.dolls - town.cultists // 2)
                if town.obelisk == 'lit' and town.cultists > town.garrison * iron:
                    if self.rng.random() < 0.1 + town.alert / 200:
                        town.obelisk = 'broken'
                        self.note(f'культисты разбили обелиск: {town.name}')

    def check_lost(self):
        share = 0.4 if self.decrees >= 1 else P['lose_share']
        for town in self.owned():
            if town.dolls < share * town.pop:
                town.owner = 'lord'
                town.obelisk = None
                town.garrison = 0
                town.dolls = 0
                town.cultists = max(town.cultists, town.base_cultists // 2)
                town.base_guards = town.orig_guards * P['regarrison']   # феодал снова ставит стражу
                town.boss_taken = town.captain_taken = town.pop_taken = False
                self.losses += 1
                self.note(f'поселение потеряно: {town.name}')

    def infiltration(self):
        for town in self.t:
            if town.owner != 'lord' or not (town.agents or town.key_agents):
                continue
            n = town.agents + town.key_agents
            cost = P['agent_feed'] * n * self.mult(town)
            fed = self.avra >= cost
            if fed:
                self.pay('agents', cost)
                town.unfed = 0
                cap = town.agents + 2 * town.key_agents
                share = DEVOUT[town.faith]
                conv = binom(self.rng, cap, 1 - share / 2)
                town.dolls = min(town.pop, town.dolls + conv)
            else:
                town.unfed += 1
            p = P['expose_per_cultist'] * town.cultists * (1.5 if town.alert >= P['reinforce_at'] else 1.0)
            if town.unfed >= 3:
                p += 0.2
            for kind in ('agents', 'key_agents'):
                lost = binom(self.rng, getattr(town, kind), p)
                if lost:
                    setattr(town, kind, getattr(town, kind) - lost)
                    town.alert += P['alert_exposed'] * lost
                    self.note(f'раскрыт агент: {town.name}')
            quiet = town.boss not in NO_ABDUCT
            if quiet and town.dolls >= 2 / 3 * town.pop:
                self.capture(town, how='инфильтрация')

    def alerts(self, active):
        for town in self.t:
            if town.owner != 'lord':
                continue
            if town.alert >= P['patrol_at']:
                self.patrol(town, active)
                town.alert = P['reinforce_at']
            town.alert = max(0.0, town.alert - P['alert_decay'])

    def nearest_owned(self, start):
        seen, q = {start.i}, [start.i]
        while q:
            i = q.pop(0)
            for j in ROADS[i]:
                if j in seen:
                    continue
                seen.add(j)
                if self.t[j].owner == 'mask' and j != 0:
                    return self.t[j]
                q.append(j)
        return None

    def patrol(self, source, active):
        target = self.nearest_owned(source)
        if target is None:
            return
        win = active and self.ok(10) >= P['patrol_pass']
        if win:
            self.avra += 20 + 10 * P['avra_per_correct']
            self.note(f'отбита стража у {target.name}')
            return
        iron = 2 if self.decrees >= 2 else 1
        freed = max(0, 10 - 2 * target.garrison * iron)
        target.dolls = max(0, target.dolls - freed)
        if target.obelisk == 'lit':
            target.obelisk = 'broken'
        self.note(f'стража прорвалась в {target.name}')

    # ---------- действия ----------
    def capture(self, town, how):
        town.owner = 'mask'
        town.grace = P['grace']
        self.army += town.agents
        town.agents = town.key_agents = 0
        if town.i not in self.first_capture:
            self.first_capture[town.i] = self.day
        self.note(f'захвачено ({how}): {town.name}')
        if town.boss == 'crimson':
            for x in self.t:
                x.faith = max(0, x.faith - 1)
        if town.boss == 'lord' and self.done is None:
            self.done = self.day

    def assault(self, town, squad):
        self.pay('assault', P['assault_cost'] * squad * self.mult(town))
        self.army -= squad
        bonus = 0
        if town.boss and not town.boss_taken:
            right = self.ok(P['boss_questions'])
            self.avra += right * P['avra_per_correct']
            if right >= P['boss_pass']:
                self.avra += P['boss_avra']
                bonus += 2
            else:
                self.fail_assault(town, squad, 'проигран бой с боссом')
                return False
        q = min(10 + int(town.guards()), 30)
        right = self.ok(q)
        self.avra += right * P['avra_per_correct']
        errors = q - right
        dead = min(errors, squad)
        squad -= dead
        self.bodies += [self.day + P['body_days']] * dead
        d = town.defense()
        eff = squad + 2 * town.dolls
        ratio = eff / d if d > 0 else 1e9
        bonus += next(b for lim, b in P['ratio_bonus'] if ratio < lim)
        if errors == 0:
            bonus += 2
        if self.decrees >= 3:
            bonus += 2
        roll = self.rng.randint(1, 20)
        total = roll + bonus
        if roll == 1:
            total = 1
        if roll == 20:
            total = 99
        kind = next(row for row in P['assault_table'] if total <= row[0])
        if kind[1] == 'fail':
            self.fail_assault(town, squad, f'бросок {roll}{bonus:+d}')
            return False
        _, name, kill, flee, loss = kind
        extra = min(squad, int(round(d * loss)))
        self.bodies += [self.day + P['body_days']] * extra
        self.army += squad - extra
        free = town.pop - town.dolls
        killed, fled = int(round(free * kill)), int(round(free * flee))
        self.bodies += [self.day + P['body_days']] * (killed + int(town.guards()) + town.cultists)
        town.pop -= killed + fled
        town.dolls = town.pop
        town.base_guards = 0
        town.cultists = 0
        for j in ROADS[town.i]:
            self.t[j].alert += P['alert_flee'] * fled
        self.capture(town, how=f'штурм, {name}, бросок {roll}{bonus:+d}')
        return True

    def fail_assault(self, town, squad, why):
        lost = squad // 2
        self.bodies += [self.day + P['body_days']] * lost
        self.army += squad - lost
        town.alert += 10
        self.note(f'штурм отбит ({why}): {town.name}')

    def sortie(self, town, key=None):
        if self.army < 3:
            return
        self.pay('sortie', P['sortie_cost'] * self.mult(town))
        q = 10 if key else 5
        right = self.ok(q)
        self.avra += right * P['avra_per_correct']
        bonus = right - self.sortie_penalty(town)
        roll = self.rng.randint(1, 20)
        total = 1 if roll == 1 else (99 if roll == 20 else roll + bonus)
        if total <= 5:
            self.army -= 3
            town.alert += P['alert_failed_sortie']
            self.note(f'вылазка провалена, отряд не вернулся: {town.name}')
            return
        if key:
            if total >= P['key_need']:
                town.alert += P['alert_key']
                if key == 'captain':
                    town.captain_taken = True
                if key == 'pop':
                    town.pop_taken = True
                    town.cultists //= 2
                    town.faith = max(0, town.faith - 1)
                if town.boss == key:
                    town.boss_taken = True
                self.captives.append(self.day + P['captive_days'])
                self.note(f'похищен {key}: {town.name}')
            return
        n = next(k for lim, k in P['sortie_table'] if total <= lim)
        if town.owner == 'mask':
            n = min(n, town.cultists)
            town.cultists -= n
        else:
            n = min(n, town.pop - town.dolls)
            town.pop -= n
        if total < 99:
            town.alert += P['alert_abduct'] * n
        self.captives += [self.day + P['captive_days']] * n

    def room(self, town):
        """Сколько кукол ещё можно забрать из поселения в войско."""
        return min(int(P['take_share'] * town.base_pop) - town.taken_to_army,
                   town.pop - int(P['take_share'] * town.base_pop))

    def sortie_fail_chance(self, town):
        bonus = 5 * P['accuracy'] - self.sortie_penalty(town)
        return min(1.0, max(0.05, (6 - bonus) / 20))

    def sortie_penalty(self, town):
        return min(P['guard_pen_cap'], int(town.guards()) // 2) + int(town.alert) // 20

    def key_chance(self, town):
        need = P['key_need'] - (10 * P['accuracy'] - self.sortie_penalty(town))
        return max(0.05, min(1.0, (21 - math.ceil(need)) / 20))

    def expose_rate(self, town):
        return P['expose_per_cultist'] * town.cultists * (1.5 if town.alert >= P['reinforce_at'] else 1.0)

    def bind(self, want):
        """Взять под контроль до want марионеток: пленные, павшие, потом куклы поселений."""
        got = 0
        for pool in ('captives', 'bodies'):
            lst = getattr(self, pool)
            while got < want and lst and self.avra >= P['bind_cost']:
                lst.pop()
                self.pay('bind', P['bind_cost'])
                self.army += 1
                got += 1
        while got < want and self.cemetery > 0 and self.avra >= P['bind_cost']:
            self.cemetery -= 1
            self.pay('bind', P['bind_cost'])
            self.army += 1
            got += 1
        for town in sorted(self.owned(), key=lambda x: -x.dolls):
            room = self.room(town)
            while got < want and room > 0 and town.dolls > 0 and self.avra >= P['bind_cost']:
                town.dolls -= 1
                town.pop -= 1
                town.taken_to_army += 1
                room -= 1
                self.pay('bind', P['bind_cost'])
                self.army += 1
                got += 1
        return got

    def bot(self):
        # обелиски: каждому своему поселению — зона
        for town in self.owned():
            if self.covering(town) is None:
                if town.obelisk == 'broken' and self.avra >= P['obelisk_restore']:
                    town.obelisk, town.charge = 'lit', 100.0
                    self.pay('obelisk', P['obelisk_restore'])
                elif town.obelisk is None and self.avra >= P['obelisk_cost']:
                    town.obelisk, town.charge = 'lit', 100.0
                    self.pay('obelisk', P['obelisk_cost'])
            if town.cultists and self.army > town.cultists + 2 and town.garrison <= town.cultists:
                need = town.cultists + 1 - town.garrison
                self.army -= need
                town.garrison += need
        # указы — по мере грамматики
        pace = DECREE_PACE[self.profile]
        if self.decrees < 3 and self.day >= P['decree_days'][self.decrees] * pace:
            cost = P['decree_cost'][self.decrees]
            if self.avra >= cost + 100:
                self.pay('decree', cost)
                self.decrees += 1
        # дешёвые марионетки, пока не пропали
        self.bind(len(self.captives) + len(self.bodies))
        # культистов в своих поселениях уводим на вылазках
        for town in self.owned():
            if town.cultists and self.avra >= 60:
                self.sortie(town)
                break
        target = next((x for x in self.t if x.owner == 'lord'), None)
        if target is None:
            return
        if target.i == 4:
            # крепость берут только сочетанием: поп, капитан, куклы внутри, потом штурм
            for key, flag in (('pop', 'pop_taken'), ('captain', 'captain_taken')):
                if (not getattr(target, flag) and self.avra >= 80 and self.army >= 6
                        and target.alert < P['reinforce_at'] and self.key_chance(target) >= 0.25):
                    self.sortie(target, key=key)
                    break
            if (target.agents < P['max_agents'] and self.army > 30 and self.expose_rate(target) <= 0.05
                    and target.alert < P['reinforce_at']):
                n = min(P['max_agents'] - target.agents, self.army - 30)
                self.army -= n
                target.agents += n
        d = target.defense()
        desired = max(3, math.ceil(2 * d - 2 * target.dolls))
        squad = desired
        lack = max(0, squad - self.army)
        cost = lack * P['bind_cost'] + squad * P['assault_cost'] * self.mult(target)
        if target.i == 4 and target.agents >= 5 and target.dolls < 0.5 * target.pop:
            return          # сначала куклы внутри
        if self.avra >= cost:
            self.bind(lack)
            if self.army >= squad:
                self.assault(target, min(self.army, squad))
                return
        # марионеток взять неоткуда — уводим людей на вылазках
        lack = max(0, squad - self.army)
        pool = sum(max(0, min(t.dolls, self.room(t))) for t in self.owned()) + self.cemetery
        if lack > pool + len(self.captives):
            for _ in range(2):
                if (self.army >= 6 and self.avra >= P['sortie_cost'] * 2 + 30
                        and target.pop - target.dolls >= P['sortie_min_free']
                        and target.alert < 40 and self.sortie_fail_chance(target) <= 0.2):
                    self.sortie(target)


def run(profile, seed):
    sim = Sim(profile, seed)
    for _ in range(P['days']):
        sim.step()
    return sim


def summarize(profile, runs):
    sims = [run(profile, s) for s in range(runs)]
    def med(xs):
        return statistics.median(xs) if xs else None
    def pct(xs, q):
        xs = sorted(xs)
        return xs[min(len(xs) - 1, int(q * len(xs)))] if xs else None
    done = [s.done for s in sims if s.done is not None]
    res = dict(
        profile=profile,
        finished=len(done) / runs,
        finish_median=med(done), finish_p10=pct(done, 0.1), finish_p90=pct(done, 0.9),
        capture_median={i: med([s.first_capture[i] for s in sims if i in s.first_capture]) for i in range(1, 5)},
        losses_mean=statistics.mean(s.losses for s in sims),
        any_loss=sum(1 for s in sims if s.losses) / runs,
        owned_by_day=[statistics.mean(s.owned_series[d] for s in sims) for d in range(P['days'])],
        spent={k: statistics.mean(s.spent[k] for s in sims) for k in sims[0].spent},
        army_max_median=med([max(s.army_series) for s in sims]),
        army_min_median=med([min(s.army_series[30:]) for s in sims]),
    )
    gap = {'away_week': (29, 37), 'quit_2w': (39, 54)}.get(profile)
    if gap:
        before, back = gap
        lost = [s.owned_series[before] - min(s.owned_series[before:back + 1]) for s in sims]
        regain = []
        for s, l in zip(sims, lost):
            if not l:
                continue
            need = s.owned_series[before]
            day = next((d for d in range(back, P['days']) if s.owned_series[d] >= need), None)
            regain.append(None if day is None else day - back)
        res['gap_lost_mean'] = statistics.mean(lost)
        res['gap_lost_dist'] = {k: lost.count(k) / runs for k in sorted(set(lost))}
        res['gap_regain_median'] = med([x for x in regain if x is not None])
        res['gap_regain_share'] = sum(1 for x in regain if x is not None) / max(1, len(regain))
    return res, sims


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--runs', type=int, default=200)
    ap.add_argument('--json')
    ap.add_argument('--log', help='профиль, для которого напечатать летопись одного прогона')
    ap.add_argument('--set', action='append', default=[], help='key=value — поменять число баланса')
    a = ap.parse_args()
    for kv in a.set:
        k, v = kv.split('=', 1)
        P[k] = json.loads(v)
    out = []
    for prof in PROFILES:
        res, sims = summarize(prof, a.runs)
        out.append(res)
        cap = ', '.join(f'{i}: {res["capture_median"][i]}' for i in range(1, 5))
        print(f'{prof:10s} финиш {res["finished"]:.0%}  медиана {res["finish_median"]} '
              f'(10%: {res["finish_p10"]}, 90%: {res["finish_p90"]})  захваты [{cap}]  '
              f'потерь {res["losses_mean"]:.2f} ({res["any_loss"]:.0%} прогонов)  армия max {res["army_max_median"]}')
        print('           траты', {k: round(v) for k, v in res['spent'].items()})
        if 'gap_lost_mean' in res:
            print(f"           за перерыв потеряно {res['gap_lost_mean']:.2f} {res['gap_lost_dist']}, "
                  f"вернул за {res['gap_regain_median']} дн. ({res['gap_regain_share']:.0%})")
        if a.log == prof:
            for d, t in sims[0].log:
                print(f'    день {d:3d}: {t}')
    if a.json:
        with open(a.json, 'w') as f:
            json.dump(out, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
