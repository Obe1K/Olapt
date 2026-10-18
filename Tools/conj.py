# -*- coding: utf-8 -*-
"""
Спряжение португальских глаголов — европейский португальский (pt-PT), орфография AO90.

Модуль не требует сторонних библиотек. Результат используется build_data.py
для создания Resources/verbs.json (приложение читает готовые таблицы).

Лица (5 слотов): eu, tu, ele/ela/você, nós, eles/elas/vocês.  «vós» не включён
(в современной речи Португалии практически не используется).
"""

PERSON_LABELS = ["eu", "tu", "ele/ela/você", "nós", "eles/elas/vocês"]
IMPERATIVE_LABELS = ["", "tu", "você", "nós", "vocês"]
CLITICS = ["me", "te", "se", "nos", "se"]

# id, название, русское пояснение, группа, русская группа, префикс, метки лиц
TENSES = [
    ("presente", "Presente", "Настоящее время", "indicativo", "Изъявительное наклонение", "", PERSON_LABELS),
    ("perfeito", "Pretérito Perfeito", "Прошедшее завершённое: «я сказал»", "indicativo", "Изъявительное наклонение", "", PERSON_LABELS),
    ("imperfeito", "Pretérito Imperfeito", "Прошедшее длительное: «я говорил», «бывало»", "indicativo", "Изъявительное наклонение", "", PERSON_LABELS),
    ("mais_que_perfeito", "Pretérito Mais-que-perfeito Simples", "Давнопрошедшее (книжное)", "indicativo", "Изъявительное наклонение", "", PERSON_LABELS),
    ("futuro", "Futuro", "Будущее время", "indicativo", "Изъявительное наклонение", "", PERSON_LABELS),
    ("condicional", "Condicional", "Условное наклонение: «я бы сказал»", "condicional", "Условное наклонение", "", PERSON_LABELS),
    ("presente_continuo", "Presente Contínuo", "Процесс сейчас: estar a + инфинитив", "perifrases", "Составные формы и перифразы", "", PERSON_LABELS),
    ("futuro_proximo", "Futuro Próximo", "Ближайшее будущее: ir + инфинитив", "perifrases", "Составные формы и перифразы", "", PERSON_LABELS),
    ("perfeito_composto", "Pretérito Perfeito Composto", "Повторяется до сих пор: ter + причастие", "perifrases", "Составные формы и перифразы", "", PERSON_LABELS),
    ("mais_que_perfeito_composto", "Pretérito Mais-que-perfeito Composto", "Давнопрошедшее (разговорное): tinha + причастие", "perifrases", "Составные формы и перифразы", "", PERSON_LABELS),
    ("conjuntivo_presente", "Conjuntivo Presente", "Сослагательное, настоящее: «que eu fale»", "conjuntivo", "Сослагательное наклонение", "que", PERSON_LABELS),
    ("conjuntivo_imperfeito", "Conjuntivo Imperfeito", "Сослагательное, прошедшее: «se eu falasse»", "conjuntivo", "Сослагательное наклонение", "se", PERSON_LABELS),
    ("conjuntivo_futuro", "Conjuntivo Futuro", "Сослагательное, будущее: «quando eu falar»", "conjuntivo", "Сослагательное наклонение", "quando", PERSON_LABELS),
    ("imperativo", "Imperativo", "Повелительное наклонение", "imperativo", "Повелительное наклонение", "", IMPERATIVE_LABELS),
    ("infinitivo_pessoal", "Infinitivo Pessoal", "Личный инфинитив: «para eu falar»", "infinitivo", "Личный инфинитив", "para", PERSON_LABELS),
]

VOWELS = "aeiouáéíóúâêô"

# ---------------------------------------------------------------- нерегулярные глаголы
# pres, pret, conj — полные списки из 5 форм. Остальное выводится по правилам.
IRREG = {
    "ser": dict(pres=["sou", "és", "é", "somos", "são"],
                pret=["fui", "foste", "foi", "fomos", "foram"],
                imperf=["era", "eras", "era", "éramos", "eram"],
                conj=["seja", "sejas", "seja", "sejamos", "sejam"],
                part="sido", tu_imp="sê"),
    "estar": dict(pres=["estou", "estás", "está", "estamos", "estão"],
                  pret=["estive", "estiveste", "esteve", "estivemos", "estiveram"],
                  conj=["esteja", "estejas", "esteja", "estejamos", "estejam"],
                  strong=True),
    "ter": dict(pres=["tenho", "tens", "tem", "temos", "têm"],
                pret=["tive", "tiveste", "teve", "tivemos", "tiveram"],
                imperf=["tinha", "tinhas", "tinha", "tínhamos", "tinham"],
                conj=["tenha", "tenhas", "tenha", "tenhamos", "tenham"],
                strong=True),
    "haver": dict(pres=["hei", "hás", "há", "havemos", "hão"],
                  pret=["houve", "houveste", "houve", "houvemos", "houveram"],
                  conj=["haja", "hajas", "haja", "hajamos", "hajam"],
                  strong=True),
    "ir": dict(pres=["vou", "vais", "vai", "vamos", "vão"],
               pret=["fui", "foste", "foi", "fomos", "foram"],
               conj=["vá", "vás", "vá", "vamos", "vão"]),
    "vir": dict(pres=["venho", "vens", "vem", "vimos", "vêm"],
                pret=["vim", "vieste", "veio", "viemos", "vieram"],
                imperf=["vinha", "vinhas", "vinha", "vínhamos", "vinham"],
                conj=["venha", "venhas", "venha", "venhamos", "venham"],
                part="vindo", strong=True),
    "fazer": dict(pres=["faço", "fazes", "faz", "fazemos", "fazem"],
                  pret=["fiz", "fizeste", "fez", "fizemos", "fizeram"],
                  conj=["faça", "faças", "faça", "façamos", "façam"],
                  fut="far", part="feito", strong=True),
    "dizer": dict(pres=["digo", "dizes", "diz", "dizemos", "dizem"],
                  pret=["disse", "disseste", "disse", "dissemos", "disseram"],
                  conj=["diga", "digas", "diga", "digamos", "digam"],
                  fut="dir", part="dito", strong=True),
    "trazer": dict(pres=["trago", "trazes", "traz", "trazemos", "trazem"],
                   pret=["trouxe", "trouxeste", "trouxe", "trouxemos", "trouxeram"],
                   conj=["traga", "tragas", "traga", "tragamos", "tragam"],
                   fut="trar", strong=True),
    "poder": dict(pres=["posso", "podes", "pode", "podemos", "podem"],
                  pret=["pude", "pudeste", "pôde", "pudemos", "puderam"],
                  conj=["possa", "possas", "possa", "possamos", "possam"],
                  strong=True),
    "querer": dict(pres=["quero", "queres", "quer", "queremos", "querem"],
                   pret=["quis", "quiseste", "quis", "quisemos", "quiseram"],
                   conj=["queira", "queiras", "queira", "queiramos", "queiram"],
                   strong=True),
    "saber": dict(pres=["sei", "sabes", "sabe", "sabemos", "sabem"],
                  pret=["soube", "soubeste", "soube", "soubemos", "souberam"],
                  conj=["saiba", "saibas", "saiba", "saibamos", "saibam"],
                  strong=True),
    "ver": dict(pres=["vejo", "vês", "vê", "vemos", "veem"],
                pret=["vi", "viste", "viu", "vimos", "viram"],
                conj=["veja", "vejas", "veja", "vejamos", "vejam"],
                part="visto"),
    "dar": dict(pres=["dou", "dás", "dá", "damos", "dão"],
                pret=["dei", "deste", "deu", "demos", "deram"],
                conj=["dê", "dês", "dê", "demos", "deem"],
                strong=True),
    "pôr": dict(pres=["ponho", "pões", "põe", "pomos", "põem"],
                pret=["pus", "puseste", "pôs", "pusemos", "puseram"],
                imperf=["punha", "punhas", "punha", "púnhamos", "punham"],
                conj=["ponha", "ponhas", "ponha", "ponhamos", "ponham"],
                fut="por", part="posto", ger="pondo", strong=True,
                inf_pessoal=["pôr", "pores", "pôr", "pormos", "porem"]),
    "ler": dict(pres=["leio", "lês", "lê", "lemos", "leem"],
                pret=["li", "leste", "leu", "lemos", "leram"],
                conj=["leia", "leias", "leia", "leiamos", "leiam"]),
    "sair": dict(pres=["saio", "sais", "sai", "saímos", "saem"],
                 pret=["saí", "saíste", "saiu", "saímos", "saíram"],
                 conj=["saia", "saias", "saia", "saiamos", "saiam"]),
    "cair": dict(pres=["caio", "cais", "cai", "caímos", "caem"],
                 pret=["caí", "caíste", "caiu", "caímos", "caíram"],
                 conj=["caia", "caias", "caia", "caiamos", "caiam"]),
    "rir": dict(pres=["rio", "ris", "ri", "rimos", "riem"],
                pret=["ri", "riste", "riu", "rimos", "riram"],
                conj=["ria", "rias", "ria", "riamos", "riam"]),
    "sorrir": dict(pres=["sorrio", "sorris", "sorri", "sorrimos", "sorriem"],
                   pret=["sorri", "sorriste", "sorriu", "sorrimos", "sorriram"],
                   conj=["sorria", "sorrias", "sorria", "sorriamos", "sorriam"]),
    "odiar": dict(pres=["odeio", "odeias", "odeia", "odiamos", "odeiam"],
                  conj=["odeie", "odeies", "odeie", "odiemos", "odeiem"]),
    "passear": dict(pres=["passeio", "passeias", "passeia", "passeamos", "passeiam"],
                    conj=["passeie", "passeies", "passeie", "passeemos", "passeiem"]),
}

IRREG.update({
    "crer": dict(pres=["creio", "crês", "crê", "cremos", "creem"],
                 pret=["cri", "creste", "creu", "cremos", "creram"],
                 conj=["creia", "creias", "creia", "creiamos", "creiam"]),
    "caber": dict(pres=["caibo", "cabes", "cabe", "cabemos", "cabem"],
                  pret=["coube", "coubeste", "coube", "coubemos", "couberam"],
                  conj=["caiba", "caibas", "caiba", "caibamos", "caibam"],
                  strong=True),
    "proibir": dict(pres=["proíbo", "proíbes", "proíbe", "proibimos", "proíbem"],
                    conj=["proíba", "proíbas", "proíba", "proibamos", "proíbam"]),
    "saudar": dict(pres=["saúdo", "saúdas", "saúda", "saudamos", "saúdam"],
                   conj=["saúde", "saúdes", "saúde", "saudemos", "saúdem"]),
    "reunir": dict(pres=["reúno", "reúnes", "reúne", "reunimos", "reúnem"],
                   conj=["reúna", "reúnas", "reúna", "reunamos", "reúnam"]),
    "doer": dict(pres=["doo", "dóis", "dói", "doemos", "doem"],
                 pret=["doí", "doeste", "doeu", "doemos", "doeram"],
                 conj=["doa", "doas", "doa", "doamos", "doam"]),
})


# roer, moer спрягаются как doer (róis, rói; roí; roía)
for _v in ["roer", "moer"]:
    IRREG[_v] = {k: ([_v[0] + x[1:] for x in v] if isinstance(v, list) else v)
                 for k, v in IRREG["doer"].items()}


def _prefixed(prefix, root):
    """Глагол-приставка по образцу корня: manter ← ter, propor ← pôr, prever ← ver."""
    out = {}
    for k, v in IRREG[root].items():
        if isinstance(v, list):
            out[k] = [prefix + x if x else x for x in v]
        elif isinstance(v, str):
            out[k] = prefix + v
        else:
            out[k] = v
    return out


def _compound(base, root, prefix):
    d = _prefixed(prefix, root)
    if root in ("ter", "vir"):
        # manténs, mantém; intervéns, intervém (ударение на приставочном глаголе)
        d["pres"][1] = prefix + ("téns" if root == "ter" else "véns")
        d["pres"][2] = prefix + ("tém" if root == "ter" else "vém")
    if root == "pôr":
        d["inf_pessoal"] = [base, base + "es", base, base + "mos", base + "em"]
    IRREG[base] = d


for _p in ["man", "ob", "con", "de", "re", "entre", "sus", "abs"]:
    _compound(_p + "ter", "ter", _p)
for _p in ["con", "inter", "pro", "sobre"]:
    _compound(_p + "vir", "vir", _p)
for _p in ["pro", "com", "su", "dis", "ex", "im", "o", "re", "de", "pressu", "decom", "recom", "trans", "sobre"]:
    _compound(_p + "por", "pôr", _p)
for _p in ["pre", "re", "ante"]:
    _compound(_p + "ver", "ver", _p)
for _p in ["des", "re", "satis"]:
    _compound(_p + "fazer", "fazer", _p)
for _p in ["contra", "des", "con"]:
    _compound(_p + "dizer", "dizer", _p)
_compound("reler", "ler", "re")

# medeio, anseio… (глаголы на -iar с чередованием: mediar, ansiar, remediar, incendiar, odiar)
MARIO = {"mediar", "ansiar", "remediar", "incendiar", "intermediar"}
# constróis, constrói, constroem
CONSTRUIR = {"construir", "destruir", "reconstruir"}

# Правильные по окончаниям, но с чередованием в корне:
#   eu  — основа 1-го лица ед. числа (без -o), alt — основа для tu/ele/eles
SPEC = {
    "ouvir": dict(eu="ouç", alt="ouv"),
    "pedir": dict(eu="peç", alt="ped"),
    "dormir": dict(eu="durm", alt="dorm"),
    "seguir": dict(eu="sig", alt="segu"),
    "conseguir": dict(eu="consig", alt="consegu"),
    "sentir": dict(eu="sint", alt="sent"),
    "preferir": dict(eu="prefir", alt="prefer"),
    "servir": dict(eu="sirv", alt="serv"),
    "vestir": dict(eu="vist", alt="vest"),
    "repetir": dict(eu="repit", alt="repet"),
    "refletir": dict(eu="reflit", alt="reflet"),
    "divertir": dict(eu="divirt", alt="divert"),
    "fugir": dict(eu="fuj", alt="fog"),
    "subir": dict(eu="sub", alt="sob"),
    "cobrir": dict(eu="cubr", alt="cobr", part="coberto"),
    "perder": dict(eu="perc", alt="perd"),
    "valer": dict(eu="valh", alt="val"),
    "abrir": dict(part="aberto"),
    "reabrir": dict(part="reaberto"),
    "entreabrir": dict(part="entreaberto"),
    "encobrir": dict(eu="encubr", alt="encobr", part="encoberto"),
    "escrever": dict(part="escrito"),
    "ganhar": dict(part="ganho"),
    "gastar": dict(part="gasto"),
    "pagar": dict(part="pago"),
    "aceitar": dict(part="aceite"),
    "entregar": dict(part="entregue"),
    "descrever": dict(part="descrito"),
    "reescrever": dict(part="reescrito"),
    "inscrever": dict(part="inscrito"),
    "gerir": dict(eu="gir", alt="ger"),
    "mentir": dict(eu="mint", alt="ment"),
    "desmentir": dict(eu="desmint", alt="desment"),
    "consentir": dict(eu="consint", alt="consent"),
    "pressentir": dict(eu="pressint", alt="pressent"),
    "sugerir": dict(eu="sugir", alt="suger"),
    "referir": dict(eu="refir", alt="refer"),
    "conferir": dict(eu="confir", alt="confer"),
    "transferir": dict(eu="transfir", alt="transfer"),
    "interferir": dict(eu="interfir", alt="interfer"),
    "digerir": dict(eu="digir", alt="diger"),
    "ferir": dict(eu="fir", alt="fer"),
    "aderir": dict(eu="adir", alt="ader"),
    "competir": dict(eu="compit", alt="compet"),
    "despir": dict(eu="disp", alt="desp"),
    "investir": dict(eu="invist", alt="invest"),
    "advertir": dict(eu="advirt", alt="advert"),
    "perseguir": dict(eu="persig", alt="persegu"),
    "prosseguir": dict(eu="prossig", alt="prossegu"),
    "descobrir": dict(eu="descubr", alt="descobr", part="descoberto"),
    "tossir": dict(eu="tuss", alt="toss"),
    "engolir": dict(eu="engul", alt="engol"),
    "polir": dict(eu="pul", alt="pul"),
    "erguer": dict(eu="erg", alt="ergu"),
    "repelir": dict(eu="repil", alt="repel"),
    "ingerir": dict(eu="ingir", alt="inger"),
    "sacudir": dict(eu="sacud", alt="sacod"),
    "acudir": dict(eu="acud", alt="acod"),
    "cuspir": dict(eu="cusp", alt="cosp"),
    "consumir": dict(eu="consum", alt="consom"),
    "sumir": dict(eu="sum", alt="som"),
    "agredir": dict(eu="agrid", alt="agrid"),
    "progredir": dict(eu="progrid", alt="progrid"),
    "transgredir": dict(eu="transgrid", alt="transgrid"),
    "prevenir": dict(eu="previn", alt="previn"),
    "medir": dict(eu="meç", alt="med"),
    "impedir": dict(eu="impeç", alt="imped"),
    "despedir": dict(eu="despeç", alt="desped"),
    "expedir": dict(eu="expeç", alt="exped"),
}

PRET_REG = {
    "ar": ["ei", "aste", "ou", "ámos", "aram"],
    "er": ["i", "este", "eu", "emos", "eram"],
    "ir": ["i", "iste", "iu", "imos", "iram"],
}
PRES_REG = {
    "ar": ["o", "as", "a", "amos", "am"],
    "er": ["o", "es", "e", "emos", "em"],
    "ir": ["o", "es", "e", "imos", "em"],
}
CONJ_REG = {
    "ar": ["e", "es", "e", "emos", "em"],
    "er": ["a", "as", "a", "amos", "am"],
    "ir": ["a", "as", "a", "amos", "am"],
}


def _theme(base):
    if base == "pôr":
        return "or"
    return base[-2:]


def _hiatus(stem):
    """Основа заканчивается гласной, образующей hiato с -i- (sa-ir, ca-ir, constru-ir; но не segu-ir)."""
    if not stem:
        return False
    if stem[-1] in "aeo":
        return True
    return stem[-1] == "u" and len(stem) > 1 and stem[-2] not in "gq"


def _accent_nos(stem, strong, theme):
    """Ударная гласная перед -ramos / -ssemos (faláramos, comêramos, fizéramos, fôramos)."""
    last = stem[-1]
    if last in "áéíóúâêô":
        return stem
    if last == "a":
        return stem[:-1] + "á"
    if last == "i":
        return stem[:-1] + "í"
    if last == "o":
        return stem[:-1] + "ô"
    if last == "e":
        if strong or theme == "ar":
            return stem[:-1] + "é"
        return stem[:-1] + "ê"
    raise ValueError("не могу поставить ударение в основе: " + stem)


def _pattern(base):
    """Типовые группы, которые спрягаются по общему образцу."""
    if base in MARIO:
        return "mario"
    if base in CONSTRUIR:
        return "construir"
    if base.endswith("ear"):
        return "ear"
    if base.endswith("air"):
        return "air"
    if base.endswith("uir") and not base.endswith(("guir", "quir")):
        return "uir"
    return ""


def base_forms(base):
    """Возвращает словарь с основными формами глагола (без возвратного местоимения)."""
    irr = IRREG.get(base)
    spec = SPEC.get(base, {})
    theme = _theme(base)
    stem = base[:-2] if theme != "or" else "p"
    out = {}

    # ---- presente
    pattern = _pattern(base) if not irr else ""
    if irr and "pres" in irr:
        pres = list(irr["pres"])
    elif pattern == "ear":
        pres = [stem + "io", stem + "ias", stem + "ia", stem + "amos", stem + "iam"]
    elif pattern == "mario":
        s3 = base[:-3]
        pres = [s3 + "eio", s3 + "eias", s3 + "eia", stem + "amos", s3 + "eiam"]
    elif pattern in ("air", "uir", "construir"):
        pres = [stem + ("io" if pattern == "air" else "o"), stem + "is", stem + "i", stem + "ímos", stem + "em"]
        if pattern == "construir":
            pres[1] = stem[:-1] + "óis"
            pres[2] = stem[:-1] + "ói"
            pres[4] = stem[:-1] + "oem"
    else:
        e = PRES_REG[theme]
        eu_stem = spec.get("eu")
        if eu_stem is None:
            eu_stem = stem
            if theme == "er" and stem.endswith("c"):
                eu_stem = stem[:-1] + "ç"          # conhecer -> conheço
            elif theme in ("er", "ir") and (stem.endswith("g")) and base[-3:] in ("ger", "gir"):
                eu_stem = stem[:-1] + "j"          # dirigir -> dirijo
            elif theme == "ir" and stem.endswith("gu"):
                eu_stem = stem[:-1]                # distinguir -> distingo
        alt = spec.get("alt", stem)
        pres = [eu_stem + e[0], alt + e[1], alt + e[2], stem + e[3], alt + e[4]]
        if theme == "ir" and base.endswith("zir"):
            pres[2] = alt                      # produzir -> produz
    out["pres"] = pres

    # ---- pretérito perfeito
    if irr and "pret" in irr:
        pret = list(irr["pret"])
    elif pattern in ("air", "uir", "construir"):
        pret = [stem + "í", stem + "íste", stem + "iu", stem + "ímos", stem + "íram"]
    else:
        e = PRET_REG[theme]
        pret = [stem + x for x in e]
        if theme == "ar":
            if base.endswith("car"):
                pret[0] = stem[:-1] + "quei"
            elif base.endswith("çar"):
                pret[0] = stem[:-1] + "cei"
            elif base.endswith("gar"):
                pret[0] = stem + "uei"
    out["pret"] = pret

    # ---- imperfeito
    if irr and "imperf" in irr:
        imperf = list(irr["imperf"])
    elif theme == "ar":
        imperf = [stem + x for x in ["ava", "avas", "ava", "ávamos", "avam"]]
    else:
        if _hiatus(stem):
            imperf = [stem + x for x in ["ía", "ías", "ía", "íamos", "íam"]]
        else:
            imperf = [stem + x for x in ["ia", "ias", "ia", "íamos", "iam"]]
    out["imperf"] = imperf

    # ---- conjuntivo presente
    if irr and "conj" in irr:
        conj = list(irr["conj"])
    elif pattern == "ear":
        conj = [stem + "ie", stem + "ies", stem + "ie", stem + "emos", stem + "iem"]
    elif pattern == "mario":
        s3 = base[:-3]
        conj = [s3 + "eie", s3 + "eies", s3 + "eie", stem + "emos", s3 + "eiem"]
    elif pattern == "air":
        conj = [stem + x for x in ["ia", "ias", "ia", "iamos", "iam"]]
    elif pattern in ("uir", "construir"):
        conj = [stem + x for x in ["a", "as", "a", "amos", "am"]]
    else:
        cs = pres[0][:-1]
        if theme == "ar":
            if base.endswith("car"):
                cs = stem[:-1] + "qu"
            elif base.endswith("çar"):
                cs = stem[:-1] + "c"
            elif base.endswith("gar"):
                cs = stem + "u"
        conj = [cs + x for x in CONJ_REG[theme]]
    out["conj"] = conj

    # ---- прочее
    out["fut"] = irr.get("fut") if irr and "fut" in irr else base
    out["strong"] = bool(irr and irr.get("strong"))
    out["theme"] = theme if theme != "or" else "er"

    if irr and "part" in irr:
        out["part"] = irr["part"]
    elif "part" in spec:
        out["part"] = spec["part"]
    elif theme == "ar":
        out["part"] = stem + "ado"
    else:
        out["part"] = stem + ("ído" if _hiatus(stem) else "ido")

    if irr and "ger" in irr:
        out["ger"] = irr["ger"]
    else:
        out["ger"] = stem + {"ar": "ando", "er": "endo", "ir": "indo"}[theme if theme != "or" else "er"]

    out["tu_imp"] = irr.get("tu_imp") if irr and "tu_imp" in irr else pres[2]
    out["inf_pessoal"] = irr.get("inf_pessoal") if irr and "inf_pessoal" in irr else None
    return out


def enclitic(form, person):
    """Присоединить энклитику: chamo-me, chamamo-nos, chama-se."""
    cl = CLITICS[person]
    if cl == "nos" and form.endswith("s"):
        form = form[:-1]
    return form + "-" + cl


def simple_tenses(base, b):
    """Простые времена (без возвратных местоимений)."""
    t = {}
    t["presente"] = b["pres"]
    t["perfeito"] = b["pret"]
    t["imperfeito"] = b["imperf"]

    # mais-que-perfeito, conjuntivo imperfeito и futuro — от 3 л. мн. ч. perfeito
    p3 = b["pret"][4]
    assert p3.endswith("ram"), (base, p3)
    st = p3[:-3]
    nos = _accent_nos(st, b["strong"], b["theme"])
    t["mais_que_perfeito"] = [st + "ra", st + "ras", st + "ra", nos + "ramos", st + "ram"]
    t["conjuntivo_imperfeito"] = [st + "sse", st + "sses", st + "sse", nos + "ssemos", st + "ssem"]
    if st.endswith("í"):  # sair: sair, saíres, sair, sairmos, saírem
        sb = st[:-1] + "i"
        t["conjuntivo_futuro"] = [sb + "r", st + "res", sb + "r", sb + "rmos", st + "rem"]
    else:
        t["conjuntivo_futuro"] = [st + "r", st + "res", st + "r", st + "rmos", st + "rem"]

    fs = b["fut"]
    t["futuro"] = [fs + x for x in ["ei", "ás", "á", "emos", "ão"]]
    t["condicional"] = [fs + x for x in ["ia", "ias", "ia", "íamos", "iam"]]
    t["conjuntivo_presente"] = b["conj"]

    imp_tu = b["tu_imp"]
    t["imperativo"] = ["", imp_tu, b["conj"][2], b["conj"][3], b["conj"][4]]

    if b["inf_pessoal"]:
        t["infinitivo_pessoal"] = list(b["inf_pessoal"])
    elif base.endswith("air") or _pattern(base) in ("uir", "construir"):
        t["infinitivo_pessoal"] = [base, base[:-2] + "íres", base, base + "mos", base[:-2] + "írem"]
    else:
        t["infinitivo_pessoal"] = [base, base + "es", base, base + "mos", base + "em"]
    return t


def conjugate(inf):
    """Полная таблица для инфинитива (с «-se» для возвратных)."""
    reflexive = inf.endswith("-se")
    base = inf[:-3] if reflexive else inf
    b = base_forms(base)
    t = simple_tenses(base, b)

    estar = IRREG["estar"]["pres"]
    ter_pres = IRREG["ter"]["pres"]
    ter_imp = IRREG["ter"]["imperf"]
    ir_pres = IRREG["ir"]["pres"]

    forms = {}
    # --- простые времена
    for tid in ["presente", "perfeito", "imperfeito", "mais_que_perfeito"]:
        forms[tid] = [enclitic(x, i) if reflexive else x for i, x in enumerate(t[tid])]

    # --- futuro и condicional (мезоклиза у возвратных)
    if reflexive:
        fut_end = ["ei", "ás", "á", "emos", "ão"]
        con_end = ["ia", "ias", "ia", "íamos", "iam"]
        forms["futuro"] = [base + "-" + CLITICS[i] + "-" + fut_end[i] for i in range(5)]
        forms["condicional"] = [base + "-" + CLITICS[i] + "-" + con_end[i] for i in range(5)]
    else:
        forms["futuro"] = t["futuro"]
        forms["condicional"] = t["condicional"]

    # --- перифразы
    def periph(aux, mid, last):
        res = []
        for i in range(5):
            if reflexive:
                if mid is None:
                    # ter + particípio: tenho-me chamado
                    res.append(enclitic(aux[i], i) + " " + last)
                else:
                    res.append(aux[i] + " " + mid + " " + enclitic(last, i))
            else:
                res.append(aux[i] + (" " + mid if mid else "") + " " + last)
        return res

    forms["presente_continuo"] = periph(estar, "a", base)
    if reflexive:
        forms["futuro_proximo"] = [ir_pres[i] + " " + enclitic(base, i) for i in range(5)]
    else:
        forms["futuro_proximo"] = [ir_pres[i] + " " + base for i in range(5)]
    forms["perfeito_composto"] = periph(ter_pres, None, b["part"])
    forms["mais_que_perfeito_composto"] = periph(ter_imp, None, b["part"])

    # --- сослагательное: проклиза у возвратных
    for tid in ["conjuntivo_presente", "conjuntivo_imperfeito", "conjuntivo_futuro"]:
        if reflexive:
            forms[tid] = [CLITICS[i] + " " + x for i, x in enumerate(t[tid])]
        else:
            forms[tid] = t[tid]

    # --- повелительное
    imp = t["imperativo"]
    if reflexive:
        # tu: chama-te, você: chame-se, nós: chamemo-nos, vocês: chamem-se
        imp = ["" if x == "" else enclitic(x, i) for i, x in enumerate(imp)]
    forms["imperativo"] = imp

    # --- личный инфинитив
    ip = t["infinitivo_pessoal"]
    forms["infinitivo_pessoal"] = [enclitic(x, i) if reflexive else x for i, x in enumerate(ip)]

    ordered = {}
    for tid, *_ in TENSES:
        assert tid in forms, tid
        assert len(forms[tid]) == 5, (inf, tid, forms[tid])
        ordered[tid] = forms[tid]

    irregular = (base in IRREG
                 or (base in SPEC and ("eu" in SPEC[base] or base in ("abrir", "escrever", "cobrir", "descobrir")))
                 or _pattern(base) in ("ear", "mario", "air", "construir"))
    group = {"ar": "-ar", "er": "-er", "ir": "-ir", "or": "-or"}[_theme(base)]
    return {
        "inf": inf,
        "base": base,
        "reflexive": reflexive,
        "group": group,
        "irregular": bool(irregular),
        "gerund": b["ger"],
        "participle": b["part"],
        "forms": ordered,
    }


def tenses_meta():
    res = []
    for tid, name, ru, group, group_ru, prefix, labels in TENSES:
        res.append({"id": tid, "name": name, "ru": ru, "group": group,
                    "groupRu": group_ru, "prefix": prefix, "labels": labels})
    return res


if __name__ == "__main__":
    import sys
    for v in sys.argv[1:] or ["falar", "comer", "partir", "ser", "chamar-se"]:
        c = conjugate(v)
        print("=" * 60)
        print(c["inf"], "| ger:", c["gerund"], "| part:", c["participle"], "| irreg:", c["irregular"])
        for tid, name, *_ in TENSES:
            print("  %-34s %s" % (name, " · ".join(x or "—" for x in c["forms"][tid])))
