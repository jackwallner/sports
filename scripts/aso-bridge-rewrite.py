#!/usr/bin/env python3
"""
ASO bridge rewrite — rebuild name / subtitle / keywords across all fastlane locales.

Strategy (data-driven via Astro, US store, 2026-06):
  - Sports-news head terms (news/scores/recap) are owned by ESPN/Yahoo/CBS at
    difficulty 73-83 -> unwinnable. Most "sports X" long-tail sits at popularity 5
    (no volume).
  - The real winnable volume is the conversation cluster: talking points (pop 56),
    conversation starters (24 / diff 19), icebreaker (19 / 19), small talk (9 / 17).
    That vertical is owned by couples/party-card apps, NOT sports.
  - Sideline owns the unique INTERSECTION ("sports" + "conversation"). So:
      name      -> brand + the bridge phrase ("Sideline: Sports Small Talk")
      subtitle  -> localized, carries a 2nd high-relevance term per English store
      keywords  -> conversation cluster (in-language) + LOCAL league tokens + a few
                   sports terms, single-word tokens (Apple auto-combines), deduped.
  - Same-language storefronts are DIFFERENTIATED (en-US/GB/AU/CA, es-ES/MX,
    pt-BR/PT, fr-FR/CA) instead of identical copies, so each store carries the
    leagues its users actually search.

Limits enforced: name<=30, subtitle<=30, keywords<=100 (chars).
Tokens are single words separated by commas (no spaces) wherever the language
allows it, to maximize Apple's cross-field keyword combinations.
"""
import os
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "fastlane", "metadata")
ROOT = os.path.abspath(ROOT)

SHARED_NAME = "The Gist: Sports Small Talk"  # 27 chars, brand + bridge phrase

# Subtitle overrides (English stores differentiated). Others: left untouched.
SUBTITLE = {
    "en-US": "Talking points for non-fans",
    "en-GB": "Football chat for non-fans",
    "en-AU": "Footy chat for non-fans",
    "en-CA": "Hockey chat for non-fans",
}

# keywords per locale (<=100 chars). Conversation cluster + local leagues + sport terms.
KEYWORDS = {
    "en-US": "conversation,starters,icebreaker,recap,nfl,nba,mlb,nhl,casual,fan,scores,news,daily,brief,trivia",
    "en-GB": "conversation,starters,icebreaker,premier,league,football,cricket,rugby,banter,recap,scores,news,fan",
    "en-AU": "conversation,starters,icebreaker,afl,nrl,footy,cricket,banter,mates,recap,scores,news,daily,fan",
    "en-CA": "conversation,starters,icebreaker,nhl,raptors,curling,banter,recap,scores,news,casual,fan,trivia",
    "de-DE": "gespräch,themen,smalltalk,bundesliga,fußball,basketball,zusammenfassung,ergebnisse,nachrichten,fan",
    "fr-FR": "conversation,sujets,briseglace,foot,ligue1,rugby,basket,résumé,score,actualité,quotidien,supporter",
    "fr-CA": "conversation,sujets,briseglace,hockey,lnh,canadien,foot,résumé,score,actualité,quotidien,partisan",
    "es-ES": "charla,conversación,temas,rompehielos,fútbol,laliga,baloncesto,resumen,marcador,noticias,afición",
    "es-MX": "charla,conversación,temas,rompehielos,fútbol,ligamx,béisbol,nba,resumen,marcador,noticias,afición",
    "ca": "conversa,temes,trencaglaç,futbol,bàsquet,resum,resultats,notícies,diari,afició,esport",
    "it": "conversazione,argomenti,rompighiaccio,calcio,seriea,basket,riassunto,risultati,notizie,tifoso",
    "pt-BR": "conversa,papo,assunto,quebragelo,futebol,brasileirão,vôlei,nba,resumo,placar,notícias,torcida",
    "pt-PT": "conversa,tema,quebragelo,futebol,liga,benfica,basquete,resumo,placar,notícias,diário,adepto",
    "nl-NL": "gesprek,onderwerpen,ijsbreker,voetbal,eredivisie,wielrennen,samenvatting,uitslagen,nieuws,fan",
    "pl": "rozmowa,tematy,lodołamacz,piłka,ekstraklasa,siatkówka,podsumowanie,wyniki,wiadomości,kibic",
    "sv": "konversation,ämnen,isbrytare,fotboll,allsvenskan,hockey,sammanfattning,resultat,nyheter,supporter",
    "da": "samtale,emner,isbryder,fodbold,superliga,håndbold,resumé,resultater,nyheder,daglig,fan",
    "no": "samtale,emner,isbryter,fotball,eliteserien,håndball,sammendrag,resultater,nyheter,daglig,fan",
    "fi": "keskustelu,aiheet,jäänmurtaja,jalkapallo,veikkausliiga,jääkiekko,yhteenveto,tulokset,uutiset,fani",
    "cs": "konverzace,témata,ledoborec,fotbal,liga,hokej,souhrn,výsledky,zprávy,denně,fanoušek",
    "sk": "konverzácia,témy,ľadoborec,futbal,liga,hokej,súhrn,výsledky,správy,denne,fanúšik",
    "hu": "beszélgetés,témák,jégtörő,foci,futball,kosárlabda,összefoglaló,eredmények,hírek,szurkoló",
    "ro": "conversație,subiecte,spărgător,fotbal,liga,baschet,rezumat,scoruri,știri,zilnic,suporter",
    "hr": "razgovor,teme,ledolomac,nogomet,liga,košarka,sažetak,rezultati,vijesti,dnevno,navijač",
    "el": "συζήτηση,θέματα,αθλητικά,ποδόσφαιρο,μπάσκετ,σύνοψη,σκορ,ειδήσεις,καθημερινά,οπαδός",
    "tr": "sohbet,konular,buzkıran,futbol,superlig,basketbol,özet,skorlar,haberler,günlük,taraftar",
    "ru": "разговор,темы,ледокол,футбол,хоккей,баскетбол,обзор,счёт,новости,ежедневно,болельщик",
    "uk": "розмова,теми,криголам,футбол,хокей,баскетбол,огляд,рахунок,новини,щодня,вболівальник",
    "ja": "雑談,会話,話題,野球,サッカー,Jリーグ,プロ野球,バスケ,まとめ,ニュース,ネタ",
    "ko": "잡담,대화,화제,축구,야구,KBO,농구,요약,뉴스,소식,이야깃거리",
    "zh-Hans": "聊天,话题,破冰,足球,篮球,中超,赛事,简报,新闻,谈资,体育",
    "zh-Hant": "聊天,話題,破冰,足球,籃球,中華職棒,賽事,簡報,新聞,談資,體育",
    "ar-SA": "محادثة,مواضيع,كسر الجليد,كرة القدم,كرة السلة,ملخص,نتائج,أخبار,يومي,مشجع",
    "he": "שיחה,נושאים,שובר קרח,כדורגל,כדורסל,סיכום,תוצאות,חדשות,יומי,אוהד",
    "hi": "बातचीत,विषय,क्रिकेट,आईपीएल,फुटबॉल,सारांश,स्कोर,समाचार,दैनिक,प्रशंसक",
    "th": "บทสนทนา,หัวข้อ,ฟุตบอล,บาส,สรุป,ผลบอล,ข่าว,ประจำวัน,แฟนกีฬา",
    "vi": "trò chuyện,chủ đề,bóng đá,bóng rổ,tóm tắt,tỉ số,tin tức,hàng ngày,người hâm mộ",
    "id": "obrolan,topik,pemecah,sepak bola,basket,ringkasan,skor,berita,harian,penggemar",
    "ms": "perbualan,topik,pemecah,bola sepak,basket,ringkasan,skor,berita,harian,peminat",
    "bn-BD": "আড্ডা,বিষয়,ক্রিকেট,ফুটবল,সারাংশ,স্কোর,খবর,দৈনিক,ভক্ত",
    "gu-IN": "વાતચીત,વિષય,ક્રિકેટ,આઈપીએલ,ફૂટબોલ,સારાંશ,સ્કોર,સમાચાર,દૈનિક,ચાહક",
    "kn-IN": "ಸಂಭಾಷಣೆ,ವಿಷಯ,ಕ್ರಿಕೆಟ್,ಐಪಿಎಲ್,ಫುಟ್‌ಬಾಲ್,ಸಾರಾಂಶ,ಸ್ಕೋರ್,ಸುದ್ದಿ,ಅಭಿಮಾನಿ",
    "ml-IN": "സംഭാഷണം,വിഷയം,ക്രിക്കറ്റ്,ഐപിഎൽ,ഫുട്ബോൾ,സംഗ്രഹം,സ്കോർ,വാർത്ത,ആരാധകൻ",
    "mr-IN": "संभाषण,विषय,क्रिकेट,आयपीएल,फुटबॉल,सारांश,स्कोअर,बातम्या,दैनिक,चाहता",
    "or-IN": "ବାର୍ତ୍ତାଳାପ,ବିଷୟ,କ୍ରିକେଟ୍,ଫୁଟବଲ୍,ସାରାଂଶ,ସ୍କୋର,ସମ୍ବାଦ,ଦୈନିକ,ପ୍ରଶଂସକ",
    "pa-IN": "ਗੱਲਬਾਤ,ਵਿਸ਼ੇ,ਕ੍ਰਿਕਟ,ਆਈਪੀਐਲ,ਫੁੱਟਬਾਲ,ਸਾਰ,ਸਕੋਰ,ਖ਼ਬਰਾਂ,ਪ੍ਰਸ਼ੰਸਕ",
    "ta-IN": "உரையாடல்,தலைப்பு,கிரிக்கெட்,ஐபிஎல்,கால்பந்து,சுருக்கம்,மதிப்பெண்,செய்தி,ரசிகர்",
    "te-IN": "సంభాషణ,విషయం,క్రికెట్,ఐపీఎల్,ఫుట్‌బాల్,సారాంశం,స్కోరు,వార్తలు,అభిమాని",
    "ur-PK": "گفتگو,موضوعات,کرکٹ,فٹبال,خلاصہ,اسکور,خبریں,روزانہ,مداح",
    "sl-SI": "pogovor,teme,ledolomilec,nogomet,liga,košarka,povzetek,rezultati,novice,navijač",
}


def write(path, value):
    with open(path, "w", encoding="utf-8") as f:
        f.write(value + "\n")


def main():
    locales = sorted(
        d for d in os.listdir(ROOT)
        if os.path.isdir(os.path.join(ROOT, d)) and d != "review_information"
    )
    errors, rows = [], []
    for loc in locales:
        d = os.path.join(ROOT, loc)
        # name
        if len(SHARED_NAME) > 30:
            errors.append(f"{loc}: name {len(SHARED_NAME)}>30")
        write(os.path.join(d, "name.txt"), SHARED_NAME)
        # subtitle (override only where specified)
        sub = SUBTITLE.get(loc)
        if sub is not None:
            if len(sub) > 30:
                errors.append(f"{loc}: subtitle {len(sub)}>30")
            write(os.path.join(d, "subtitle.txt"), sub)
        # keywords
        kw = KEYWORDS.get(loc)
        if kw is None:
            errors.append(f"{loc}: NO KEYWORDS DEFINED")
            continue
        if len(kw) > 100:
            errors.append(f"{loc}: keywords {len(kw)}>100 -> {kw}")
        toks = kw.split(",")
        if len(toks) != len(set(toks)):
            dupes = [t for t in set(toks) if toks.count(t) > 1]
            errors.append(f"{loc}: duplicate tokens {dupes}")
        write(os.path.join(d, "keywords.txt"), kw)
        rows.append((loc, len(kw), len(toks)))

    print(f"{'locale':10} {'kwlen':>5} {'tokens':>6}")
    for loc, ln, tk in rows:
        print(f"{loc:10} {ln:>5} {tk:>6}")
    missing = sorted(set(locales) - set(KEYWORDS) - {"review_information"})
    if missing:
        print("\nLocales with no keyword entry:", missing)
    if errors:
        print("\nERRORS:")
        for e in errors:
            print("  ", e)
        sys.exit(1)
    print(f"\nOK: {len(rows)} locales rewritten, name='{SHARED_NAME}'")


if __name__ == "__main__":
    main()
