# -*- coding: utf-8 -*-
# Фразы по-английски: названия наборов, пояснения и подсказки «в лицах», которые не выводятся шаблоном.
# Подсказки для выражений вида «to be …» / «to have …» строятся автоматически (Tools/phrasebank.py),
# для готовых фраз подсказка — их английский перевод из Tools/phrases/*.txt.

SETS = {
    "states": "States and feelings",
    "cafe": "At the café and restaurant",
    "talk": "Meeting people and conversation",
    "city": "Around town and travel",
}

NOTES = {
    "states:estar aborrecido": "In Portugal “aborrecido” means “bored” or “annoyed”, and “aborrecer-se” means “to get bored”.",
    "states:estar à espera": "This is exactly how it's said in Portugal: “Estou à espera do autocarro” — instead of the Brazilian “estou esperando”.",
    "states:ter saudades": "“Tenho saudades tuas” — I miss you. “Saudade” is one of the most Portuguese words there is.",
    "cafe:queria um café por favor": "“Queria” is more polite than “quero”. In Portugal “um café” is an espresso.",
    "cafe:pode trazer a ementa": "In Portugal the menu is “a ementa”.",
    "cafe:onde fica a casa de banho": "In Portugal it's “casa de banho”; in Brazil, “banheiro”.",
    "cafe:uma imperial por favor": "“Imperial” is a small glass of draught beer (Lisbon); in the north people say “fino”.",
    "talk:não percebo": "In Portugal people usually say “não percebo”.",
    "city:a que horas parte o comboio": "“Comboio” is a train in Portugal (in Brazil it's “trem”).",
    "city:onde fica a paragem do autocarro": "“Paragem” and “autocarro” are the words used in Portugal.",
}

# Подсказки по лицам (eu, tu, ele, ela, nós, eles), если шаблон «to be / to have» не подходит
LINES = {
    "states:ter saudades": ["I miss (someone).", "Do you miss (someone)?", "He misses (someone).",
                            "She misses (someone).", "We miss (someone).", "They miss (someone)."],
}
