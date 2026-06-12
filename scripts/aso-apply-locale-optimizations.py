#!/usr/bin/env python3
"""Apply optimized native keywords/subtitles for Sideline / sports ASO (go pipeline).

Dedupes keywords against each locale's name + subtitle (Apple indexes all three).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
CONTENT_JSON = Path(__file__).resolve().parent / "aso-locale-content.json"

BRAND_NAME = "The Gist - Sports Talk"

# Required subscription terms (App Review 3.1.2); appended to every description.
DESCRIPTION_FOOTER = """The Sideline Pro is an auto-renewing subscription (monthly or annual). Your
subscription renews automatically unless cancelled at least 24 hours before the
end of the period. Manage or cancel anytime in your Apple ID settings.
Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: https://jackwallner.github.io/sports/privacy-policy.html"""

# Native keyword fields (≤100 chars). Omit terms duplicated in name/subtitle (dedupe at write).
KEYWORDS: dict[str, str] = {
    # Strategy: "talking points" (56/23) in subtitle is the indie crown jewel.
    # Keyword field validated: each term brings up 3+/5 Sports-genre apps as "sports [term]".
    # All terms pair with "sports" from the app name in Apple index. No overlap w/ name/subtitle.
    # Pop≥6, sports-SERP-validated, prioritized by pop/diff ratio for indie winnability.
    "en-US": "conversation,icebreaker,recap,season,debate,headlines,discussion,roundup,insider,barstool,highlights",
    "en-GB": "conversation,icebreaker,recap,season,debate,headlines,discussion,roundup,insider,barstool,highlights",
    "en-AU": "conversation,icebreaker,recap,season,debate,headlines,discussion,roundup,insider,barstool,highlights",
    "en-CA": "conversation,icebreaker,recap,season,debate,headlines,discussion,roundup,insider,barstool,highlights",
    "de-DE": "gespräch,aufhänger,zusammenfassung,kurz,debste,saison,schlagzeilen,diskussion,täglich,zusammenstellung,insider,klatsch",
    "fr-FR": "conversation,brise-glace,récap,brief,saison,débat,gros titres,discussion,quotidien,initié,potins,résumé",
    "fr-CA": "conversation,brise-glace,récap,brief,saison,débat,gros titres,discussion,quotidien,initié,potins,résumé",
    "es-ES": "conversación,rompehielos,resumen,breve,temporada,debate,titulares,discusión,diario,repaso,información,chismes",
    "es-MX": "conversación,rompehielos,resumen,breve,temporada,debate,titulares,plática,diario,repaso,información,chismes",
    "ca": "conversació,trencaglaç,resum,breu,temporada,debat,titulars,discussió,diari,repàs,informat,xafarderia",
    "it": "conversazione,rompighiaccio,riepilogo,breve,stagione,dibattito,titoli,discussione,quotidiano,giro d'orizzonte,insider,pettegolezzo",
    "pt-BR": "conversa,quebra-gelo,resumo,breve,temporada,debate,manchetes,discussão,diário,resenha,informação,fofoca",
    "pt-PT": "conversa,quebra-gelo,resumo,breve,temporada,debate,títulos,discussão,diário,resenha,informação,fofoca",
    "nl-NL": "gesprek,ijsbreker,samenvatting,kort,seizoen,debat,krantenkoppen,discussie,dagelijks,overzicht,ingewijde,roddel",
    "pl": "rozmowa,lodołamacz,podsumowanie,krótki,sezon,debata,nagłówki,dyskusja,codzienny,przegląd,informator,plotki",
    "sv": "konversation,isbrytare,sammanfattning,kort,säsong,debatt,rubriker,dikussion,daglig,översikt,insider,skvaller",
    "da": "samtale,isbryder,resumé,kort,sæson,debat,overskrifter,dikussion,daglig,rundtur,insider,sladder",
    "no": "samtale,isbryter,sammendrag,kort,sesong,debatt,overskrifter,diskusjon,daglig,oversikt,insider,sladder",
    "fi": "keskustelu,jäänmurtaja,yhteenveto,lyhyt,kausi,keskustelu,otsikot,diskusio,päivittäinen,katsaus,sisaapiiri,juttu",
    "cs": "konverzace,ledoborec,souhrn,stručný,sezóna,debata,titulky,diskuze,denní,přehled,insider,drby",
    "sk": "konverzácia,ľadoborec,súhrn,stručný,sezóna,debata,titulky,diskusia,denný,prehľad,insider,drby",
    "hu": "beszélgetés,jégtörő,összefoglaló,rövid,évad,vita,fejlécek,diszkusszió,napi,áttekintés,bennfentes,pletyka",
    "ro": "conversație,spărgător de gheață,rezumat,scurt,sezon,dezbatere,titluri,discuție,zilnic,sumar,insider,bârfă",
    "hr": "razgovor,ledolomica,sažetak,kratko,sezona,debata,naslovi,rasprava,dnevno,pregled,insider,trač",
    "el": "συζήτηση,παγοθραύστης,περίληψη,σύντομο,σεζόν,συζήτηση,τίτλοι,συζήτηση,καθημερινό,ανασκόπηση,μυημένος,κουτσομπολιό",
    "tr": "sohbet,buzkıran,özet,kısa,sezon,tartışma,manşetler,tartışma,günlük,özet,insider,dedikodu",
    "ru": "разговор,ледокол,резюме,кратко,сезон,дискуссия,заголовки,обсуждение,ежедневно,обзор,инсайдер,сплетни",
    "uk": "розмова,криголам,резюме,коротко,сезон,дискусія,заголовки,обговорення,щоденно,огляд,інсайдер,плітки",
    "ja": "会話,アイスブレイク,まとめ,簡潔,シーズン,議論,見出し,討論,毎日,総集編,インサイダー,ゴシップ",
    "ko": "대화,아이스브레이크,요약,간략,시즌,토론,헤드라인,논의,매일,개괄,인사이더,가십",
    "zh-Hans": "对话,破冰,摘要,简报,赛季,讨论,头条,讨论,每日,回顾,内幕,八卦",
    "zh-Hant": "對話,破冰,摘要,簡報,賽季,討論,頭條,討論,每日,回顧,內幕,八卦",
    "ar-SA": "محادثة,كسر الجليد,ملخص,موجز,موسم,مناقشة,عناوين,نقاش,يومي,استعراض,داخلي,نميمة",
    "he": "שיחה,שובר קרח,סיכום,קצר,עונה,דיון,כותרות,דיון,יומי,סקירה,חדשות,רכילות",
    "hi": "बातचीत,बर्फ तोड़ने वाला,सारांश,संक्षिप्त,सीज़न,बहस,सुर्खियाँ,चर्चा,दैनिक,समीक्षा,इनसाइडर,गपशप",
    "th": "บทสนทนา,น้ำแข็งแตก,สรุป,สั้น,ซีซั่น,ถกเถียง,พาดหัว,อภิปราย,รายวัน,สรุปวงใน,ซุบซิบ",
    "vi": "trò chuyện,phá băng,tóm tắt,ngắn,mùa giải,tranh luận,tiêu đề,thảo luận,hàng ngày,tổng quan,nội gián,tin đồn",
    "id": "percakapan,pemecah kebekuan,ringkasan,singkat,musim,perdebatan,berita utama,diskusi bankan,harian,ikhtisar,orang dalam,gosip",
    "ms": "perbualan,pemecah ais,ringkasan,ringkas,musim,perdebatan,berita utama,perbincangan,harian,ikhtisar,dalaman,gosip",
    "bn-BD": "কথোপকথন,বরফ ভাঙ্গা,সারসংক্ষেপ,সংক্ষিপ্ত,মৌসুম,বিতর্ক,শিরোনাম,আলোচনা,দৈনিক,ওভারভিউ,ইনসাইডার,গসিপ",
    "gu-IN": "વાતચીત,બરફ તોડનાર,સારાંશ,સંક્ષિપ્ત,સીઝન,ચર્ચા,હેડલાઇન્સ,ચર્ચા,દૈનિક,ઝાંખી,ઇનસાઇડર,ગપસપ",
    "kn-IN": "ಸಂಭಾಷಣೆ,ಐಸ್‌ಬ್ರೇಕರ್,ಸಾರಾಂಶ,ಸಂಕ್ಷಿಪ್ತ,ಸೀಸನ್,ಚರ್ಚೆ,ಶೀರ್ಷಿಕೆಗಳು,ಚರ್ಚೆ,ದೈನಂದಿನ,ಅವಲೋಕನ,ಇನ್‌ಸೈಡರ್,ಗಾಸಿಪ್",
    "ml-IN": "സംഭാഷണം,ഐസ്‌ബ്രേക്കർ,ചുരുക്കം,ഹ്രസ്വം,സീസൺ,ചർച്ച,തലക്കെട്ടുകൾ,ചർച്ച,ദൈനംദിന,അവലോകനം,ഇൻസൈഡർ,ഗോസിപ്പ്",
    "mr-IN": "संभाषण,बर्फ तोडणारा,सारांश,संक्षिप्त,हंगाम,वाद,ठळक बातम्या,चर्चा,दैनंदिन,आढावा,इनसाइडर,गप्पा",
    "or-IN": "କଥାବାର୍ତ୍ତା,ବରଫ ଭଙ୍ଗକାରୀ,ସାରାଂଶ,ସଂକ୍ଷିପ୍ତ,ଋତୁ,ବିତର୍କ,ସୁର୍ଖି,ଆଲୋଚନା,ଦୈନିକ,ସମୀକ୍ଷା,ଇନସାଇଡର,ଗପ",
    "pa-IN": "ਗੱਲਬਾਤ,ਬਰਫ ਤੋੜਨ ਵਾਲਾ,ਸਾਰ,ਸੰਖੇਪ,ਸੀਜ਼ਨ,ਬਹਿਸ,ਸੁਰਖੀਆਂ,ਚਰਚਾ,ਰੋਜ਼ਾਨਾ,ਸੰਖੇਪ ਜਾਣਕਾਰੀ,ਇਨਸਾਈਡਰ,ਗੱਪ",
    "ta-IN": "உரையாடல்,ஐஸ் பிரேக்கர்,சுருக்கம்,சுருக்கமான,சீசன்,விவாதம்,தலைப்புச் செய்திகள்,விவாதம்,தினசரி,கண்ணோட்டம்,இன்சைடர்,வதந்தி",
    "te-IN": "సంభాషణ,ఐస్‌బ్రేకర్,సారాంశం,సంక్షిప్తం,సీజన్,చర్చ,హెడ్‌లైన్స్,చర్చ,రోజువారీ,అవలోకనం,ఇన్‌సైడర్,గాసిప్",
    "ur-PK": "بات چیت,برف توڑنے والا,خلاصہ,مختصر,سیزن,بحث,سرخیاں,بحث,روزانہ,جائزہ,اندرونی,گپ شپ",
    "sl-SI": "pogovor,ledolomilec,povzetek,kratko,sezona,debata,glavne novice,razprava,dnevno,pregled,insider,opravka",
}

SUBTITLES: dict[str, str] = {
    "en-US": "Talking points for non-fans",
    "en-GB": "Talking points for non-fans",
    "en-AU": "Talking points for non-fans",
    "en-CA": "Talking points for non-fans",
    "de-DE": "Gesprächstipps für Non-Fans",
    "fr-FR": "Points de conv. non-fans",
    "fr-CA": "Points de conv. non-fans",
    "es-ES": "Temas para no aficionados",
    "es-MX": "Temas para no aficionados",
    "ca": "Temes per a no aficionats",
    "it": "Punti per non tifosi",
    "pt-BR": "Papos para não torcedores",
    "pt-PT": "Papos para não adeptos",
    "nl-NL": "Gesprekstips voor non-fans",
    "pl": "Tematy dla nietifów",
    "sv": "Samtalsämnen för icke-fans",
    "da": "Samtaleemner for ikke-fans",
    "no": "Samtaleemner for ikke-fans",
    "fi": "Puheenaiheet ei-faneille",
    "cs": "Témata pro nefanoušky",
    "sk": "Témy pre nefanúšikov",
    "hu": "Témák nem szurkolóknak",
    "ro": "Subiecte pentru ne-fani",
    "hr": "Teme za ne-navijače",
    "el": "Θέματα για μη φίλους",
    "tr": "Taraftar olmayanlara",
    "ru": "Темы для не болельщиков",
    "uk": "Теми для не вболівальників",
    "ja": "非ファン向け話題",
    "ko": "비팬을 위한 화제",
    "zh-Hans": "非球迷聊天话题",
    "zh-Hant": "非球迷聊天話題",
    "ar-SA": "نقاط حديث لغير المعجبين",
    "he": "נקודות שיחה ללא אוהדים",
    "hi": "गैर-प्रशंसकों के लिए",
    "th": "หัวข้อสำหรับคนไม่แฟน",
    "vi": "Chủ đề cho người không hâm mộ",
    "id": "Topik untuk bukan penggemar",
    "ms": "Topik untuk bukan peminat",
    "bn-BD": "অ-ভক্তদের জন্য আলোচনা",
    "gu-IN": "બિન-ચાહકો માટે વાતચીત",
    "kn-IN": "ಅಭಿಮಾನಿಗಳಲ್ಲದವರಿಗೆ",
    "ml-IN": "അഭിമാനികളല്ലാത്തവർക്ക്",
    "mr-IN": "चाहत्यांसाठी नाही",
    "or-IN": "ଅଭିମାନୀ ନୁହେଁଙ୍କ ପାଇଁ",
    "pa-IN": "ਗੈਰ-ਪ੍ਰਸ਼ੰਸਕਾਂ ਲਈ",
    "ta-IN": "பக்தர்கள் அல்லாதவர்களுக்கு",
    "te-IN": "అభిమానులు కాదు వారికి",
    "ur-PK": "غیر پرستاروں کے لیے",
    "sl-SI": "Teme za ne-navijače",
}


def indexed_terms(name: str, subtitle: str) -> set[str]:
    text = f"{name} {subtitle}".lower()
    terms: set[str] = set()
    for w in re.findall(r"[a-z0-9\u0080-\uffff]+", text, flags=re.I):
        if len(w) >= 2:
            terms.add(w)
    return terms


def dedupe_keywords(name: str, subtitle: str, keywords_csv: str) -> str:
    indexed = indexed_terms(name, subtitle)
    kept: list[str] = []
    for raw in keywords_csv.split(","):
        kw = raw.strip().lower()
        if not kw:
            continue
        # Check the phrase as a whole against indexed single-word terms
        phrase_words = set(kw.split())
        # Skip if every word in the phrase is already in name/subtitle individually
        if phrase_words and phrase_words.issubset(indexed):
            continue
        # Also skip if any individual word (len>=4) matches an indexed term for single-word KW
        if " " not in kw:
            if kw in indexed:
                continue
            if any(kw == t or (len(kw) >= 4 and kw in t) or (len(t) >= 4 and t in kw) for t in indexed):
                continue
        kept.append(kw)
    return ",".join(kept)


def trim_keywords(s: str, limit: int = 100) -> str:
    # Strip whitespace around commas only, preserve multi-word phrases
    parts = [p.strip() for p in s.split(",")]
    joined = ",".join(parts)
    if len(joined) <= limit:
        return joined
    while parts and len(",".join(parts)) > limit:
        parts.pop()
    return ",".join(parts)


def trim_subtitle(s: str, limit: int = 30) -> str:
    return s[:limit] if len(s) > limit else s


def load_locale_content() -> dict[str, dict[str, str]]:
    if CONTENT_JSON.exists():
        return json.loads(CONTENT_JSON.read_text(encoding="utf-8"))
    return {}


def main() -> None:
    locale_content = load_locale_content()
    report: dict[str, dict] = {}
    for loc_dir in sorted(META.iterdir()):
        if not loc_dir.is_dir() or loc_dir.name == "review_information":
            continue
        loc = loc_dir.name
        if loc not in KEYWORDS:
            continue
        kw_path = loc_dir / "keywords.txt"
        sub_path = loc_dir / "subtitle.txt"
        name_path = loc_dir / "name.txt"
        desc_path = loc_dir / "description.txt"
        promo_path = loc_dir / "promotional_text.txt"
        old_kw = kw_path.read_text(encoding="utf-8").strip() if kw_path.exists() else ""
        old_sub = sub_path.read_text(encoding="utf-8").strip() if sub_path.exists() else ""
        old_desc = desc_path.read_text(encoding="utf-8").strip() if desc_path.exists() else ""
        name = (name_path.read_text(encoding="utf-8").strip() if name_path.exists() else "") or BRAND_NAME
        if not name_path.exists() or len(name) < 5:
            name_path.write_text(BRAND_NAME + "\n", encoding="utf-8")
            name = BRAND_NAME
        sub_for_dedupe = SUBTITLES.get(loc, old_sub)
        raw_kw = KEYWORDS[loc]
        new_kw = trim_keywords(dedupe_keywords(name, sub_for_dedupe, raw_kw))
        kw_path.write_text(new_kw + "\n", encoding="utf-8")
        new_sub = old_sub
        if loc in SUBTITLES:
            new_sub = trim_subtitle(SUBTITLES[loc])
            sub_path.write_text(new_sub + "\n", encoding="utf-8")
        content = locale_content.get(loc, locale_content.get("en-US", {}))
        new_desc = content.get("description", old_desc)
        new_promo = content.get("promotional_text", "")
        if new_desc:
            new_desc = new_desc.strip()
            if "auto-renewing subscription" not in new_desc:
                new_desc = new_desc + "\n\n" + DESCRIPTION_FOOTER
            desc_path.write_text(new_desc + "\n", encoding="utf-8")
        if new_promo:
            promo_path.write_text(new_promo.strip() + "\n", encoding="utf-8")
        report[loc] = {
            "keywords": {"old": old_kw, "new": new_kw, "len": len(new_kw)},
            "subtitle": {"old": old_sub, "new": new_sub} if loc in SUBTITLES else {},
            "description": {"localized": bool(content.get("description")), "chars": len(new_desc)},
            "promotional_text": {"localized": bool(content.get("promotional_text")), "chars": len(new_promo)},
        }
    out = ROOT / "scripts" / "aso-locale-optimization-report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Updated {len(report)} locales → {out}")


if __name__ == "__main__":
    main()
