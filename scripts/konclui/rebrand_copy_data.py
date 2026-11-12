"""The data of rebrand_copy.py: every word Koncluí changes in what upstream (Coucou) wrote, in the 14 catalog languages.

Rows list their texts in LANGS order: en, pt-BR, es, fr, de, ru, tr, id, ar, bn, hi, th, zh-Hans, zh-Hant. None leaves that language as
upstream wrote it. The second field of a row is the upstream English the row replaces; when upstream changes it, the row is
reported STALE and not applied (rebrand.py --check).

Rulebook: docs/konclui/UX.md section 5. In short: no dashes as punctuation, one name per concept (the notch is "notch", a tab
in the notch is an "aba" in pt-BR, the floating dictation indicator is the "indicador de ditado"), paths in System Settings
are written with ›, errors say what happened, the impact and the next step.
"""
from __future__ import annotations

LANGS = ("en", "pt-BR", "es", "fr", "de", "ru", "tr", "id", "ar", "bn", "hi", "th", "zh-Hans", "zh-Hant")

COPY: dict[str, tuple[str | tuple[str, ...], dict[str, str]]] = {}
SUBS: dict[str, dict[str, list[tuple[str, str]]]] = {}
FILL: dict[str, dict[str, str]] = {}
DASHES: dict[str, str] = {}
PATHS: list[str] = []
FIXED: list[tuple[str, str, str]] = []
INSERTS: list[tuple[str, str, str]] = []
USAGE: dict[str, dict[str, str]] = {}
USAGE_LANGS: tuple[str, ...] = tuple(sorted((*LANGS, "ja", "ko")))


def r(key: str, source: str | tuple[str, ...], *texts: str | None) -> None:
    """One COPY row: the key, the upstream English it replaces (or the spellings of it, a no-break space may differ), then the
    14 texts."""
    if len(texts) != len(LANGS):
        raise ValueError(f"{key!r}: {len(texts)} texts, expected {len(LANGS)}")
    if key in COPY:
        raise ValueError(f"{key!r}: two rows")
    COPY[key] = (source, {lang: text for lang, text in zip(LANGS, texts) if text is not None})


def f(key: str, de: str, th: str, tr: str) -> None:
    """One FILL row: a key upstream wrote without German, Thai and Turkish."""
    FILL[key] = {"de": de, "th": th, "tr": tr}


def s(key: str, *fixes) -> None:
    """One SUBS row: the key, then per language None, one (old, new) fragment or a list of them."""
    if len(fixes) != len(LANGS):
        raise ValueError(f"{key!r}: {len(fixes)} entries, expected {len(LANGS)}")
    if key in SUBS:
        raise ValueError(f"{key!r}: two rows")
    SUBS[key] = {lang: ([fix] if isinstance(fix, tuple) else list(fix))
                 for lang, fix in zip(LANGS, fixes) if fix is not None}


def u(key: str, *texts: str) -> None:
    """One Info.plist usage description's 14-language base row; ko/ja are added below."""
    if len(texts) != len(LANGS):
        raise ValueError(f"{key!r}: {len(texts)} texts, expected {len(LANGS)}")
    USAGE[key] = dict(zip(LANGS, texts))


# ---------------------------------------------------------------------------------------------
# macOS permission prompts (A3-11). Info.plist keeps the English (project.yml, edited by FIXED below); all 16 languages
# are NotchBuddy/Resources/InfoPlist.xcstrings, which test-copy.py checks against this table. Each line says what the
# app really does with the permission (the code was read for it), because people decide on trust from these lines.

u("NSMicrophoneUsageDescription",
  "Koncluí uses the microphone when you dictate, say “OK Koru”, or ask it to note a call.",
  "O Koncluí usa o microfone quando você dita, diz “OK Koru” ou pede para anotar uma chamada.",
  "Koncluí usa el micrófono cuando dictas, dices «OK Koru» o le pides que tome notas de una llamada.",
  "Koncluí utilise le micro quand tu dictes, dis « OK Koru » ou lui demandes de prendre des notes pendant un appel.",
  "Koncluí nutzt das Mikrofon, wenn du diktierst, „OK Koru“ sagst oder ein Gespräch mitschreiben lässt.",
  "Koncluí использует микрофон, когда вы диктуете, говорите «OK Koru» или просите записать заметки о звонке.",
  "Koncluí, dikte ettiğinde, “OK Koru” dediğinde veya bir görüşmeyi not etmesini istediğinde mikrofonu kullanır.",
  "Koncluí memakai mikrofon saat kamu mendikte, mengucap “OK Koru”, atau memintanya mencatat panggilan.",
  "يستخدم Koncluí الميكروفون عندما تُملي أو تقول «OK Koru» أو تطلب منه تدوين مكالمة.",
  "আপনি যখন ডিক্টেট করেন, “OK Koru” বলেন বা কোনো কল নোট করতে বলেন, তখন Koncluí মাইক্রোফোন ব্যবহার করে।",
  "जब आप डिक्टेट करते हैं, “OK Koru” बोलते हैं या किसी कॉल के नोट्स बनवाते हैं, तब Koncluí माइक्रोफ़ोन का उपयोग करता है।",
  "Koncluí ใช้ไมโครโฟนเมื่อคุณป้อนข้อความด้วยเสียง พูดว่า “OK Koru” หรือสั่งให้จดบันทึกการโทร",
  "当你听写、说“OK Koru”或让 Koncluí 记录通话时，它会使用麦克风。",
  "當你聽寫、說「OK Koru」或請 Koncluí 記錄通話時，它會使用麥克風。")

u("NSAudioCaptureUsageDescription",
  "Koncluí records what your Mac plays only while you note a call, to write down what the other people say.",
  "O Koncluí grava o que o seu Mac reproduz só enquanto você anota uma chamada, para registrar o que as outras pessoas dizem.",
  "Koncluí graba lo que reproduce tu Mac solo mientras tomas notas de una llamada, para escribir lo que dicen las demás personas.",
  "Koncluí enregistre ce que ton Mac joue uniquement pendant que tu prends des notes d'un appel, pour transcrire ce que disent les autres.",
  "Koncluí nimmt nur während eines Gesprächs, das du mitschreiben lässt, auf, was dein Mac abspielt, um festzuhalten, was die anderen sagen.",
  "Koncluí записывает то, что воспроизводит ваш Mac, только пока вы ведёте заметки о звонке, чтобы записать слова собеседников.",
  "Koncluí, Mac'inin çaldığı sesi yalnızca bir görüşmeyi not ederken kaydeder; diğer kişilerin söylediklerini yazıya dökmek için.",
  "Koncluí merekam suara yang diputar Mac-mu hanya saat kamu mencatat panggilan, untuk menuliskan ucapan orang lain.",
  "يسجّل Koncluí ما يُشغّله جهاز Mac فقط أثناء تدوين مكالمة، ليكتب ما يقوله الآخرون.",
  "আপনি কোনো কল নোট করার সময়ই শুধু Koncluí আপনার Mac যা চালায় তা রেকর্ড করে, অন্য মানুষেরা যা বলে তা লিখে রাখতে।",
  "आप किसी कॉल के नोट्स बनाते हैं तभी Koncluí आपका Mac जो बजाता है उसे रिकॉर्ड करता है, ताकि दूसरे लोग जो कहते हैं वह लिख सके।",
  "Koncluí บันทึกเสียงที่ Mac ของคุณเล่นเฉพาะขณะที่คุณจดบันทึกการโทร เพื่อเขียนสิ่งที่คนอื่นพูด",
  "仅在你记录通话期间，Koncluí 才会录制 Mac 播放的声音，用来写下其他人说的话。",
  "只有在你記錄通話期間，Koncluí 才會錄下 Mac 播放的聲音，用來寫下其他人說的話。")

u("NSSpeechRecognitionUsageDescription",
  "Koncluí turns your voice into text when you dictate, say “OK Koru”, or note a call. Your Mac does the recognition, on the device when it can.",
  "O Koncluí transforma sua voz em texto quando você dita, diz “OK Koru” ou anota uma chamada. Quem reconhece a fala é o seu Mac, no próprio aparelho quando possível.",
  "Koncluí convierte tu voz en texto cuando dictas, dices «OK Koru» o tomas notas de una llamada. El reconocimiento lo hace tu Mac, en el propio dispositivo cuando es posible.",
  "Koncluí transforme ta voix en texte quand tu dictes, dis « OK Koru » ou prends des notes d'un appel. La reconnaissance est faite par ton Mac, sur l'appareil quand c'est possible.",
  "Koncluí wandelt deine Stimme in Text um, wenn du diktierst, „OK Koru“ sagst oder ein Gespräch mitschreibst. Die Erkennung übernimmt dein Mac, wenn möglich direkt auf dem Gerät.",
  "Koncluí превращает ваш голос в текст, когда вы диктуете, говорите «OK Koru» или ведёте заметки о звонке. Речь распознаёт ваш Mac, по возможности прямо на устройстве.",
  "Koncluí, dikte ettiğinde, “OK Koru” dediğinde veya bir görüşmeyi not ettiğinde sesini metne çevirir. Tanımayı Mac'in yapar; mümkünse cihazın üzerinde.",
  "Koncluí mengubah suaramu menjadi teks saat kamu mendikte, mengucap “OK Koru”, atau mencatat panggilan. Pengenalan ucapan dilakukan Mac-mu, di perangkat jika memungkinkan.",
  "يحوّل Koncluí صوتك إلى نص عندما تُملي أو تقول «OK Koru» أو تدوّن مكالمة. يتولى جهاز Mac التعرف على الكلام، على الجهاز نفسه متى أمكن.",
  "আপনি ডিক্টেট করলে, “OK Koru” বললে বা কল নোট করলে Koncluí আপনার কণ্ঠকে টেক্সটে বদলায়। শনাক্ত করে আপনার Mac, সম্ভব হলে ডিভাইসেই।",
  "आप डिक्टेट करते हैं, “OK Koru” बोलते हैं या कॉल के नोट्स बनाते हैं, तब Koncluí आपकी आवाज़ को टेक्स्ट में बदलता है। पहचान आपका Mac करता है, संभव हो तो डिवाइस पर ही।",
  "Koncluí แปลงเสียงของคุณเป็นข้อความเมื่อคุณป้อนข้อความด้วยเสียง พูดว่า “OK Koru” หรือจดบันทึกการโทร Mac ของคุณเป็นผู้ถอดเสียง โดยทำบนอุปกรณ์เมื่อทำได้",
  "当你听写、说“OK Koru”或记录通话时，Koncluí 会把你的语音转成文字。识别由你的 Mac 完成，条件允许时在设备上进行。",
  "當你聽寫、說「OK Koru」或記錄通話時，Koncluí 會把你的語音轉成文字。辨識由你的 Mac 完成，條件允許時在裝置上進行。")

u("NSAccessibilityUsageDescription",
  "Koncluí needs Accessibility to paste what you dictate, to hear the Esc key, and to read the title of the window you attach.",
  "O Koncluí precisa de Acessibilidade para colar o que você dita, ouvir a tecla Esc e ler o título da janela que você anexa.",
  "Koncluí necesita Accesibilidad para pegar lo que dictas, detectar la tecla Esc y leer el título de la ventana que adjuntas.",
  "Koncluí a besoin de l'Accessibilité pour coller ce que tu dictes, détecter la touche Échap et lire le titre de la fenêtre que tu joins.",
  "Koncluí braucht die Bedienungshilfen, um Diktiertes einzufügen, die Esc-Taste zu erkennen und den Titel des Fensters zu lesen, das du anhängst.",
  "Koncluí нужно разрешение «Универсальный доступ», чтобы вставлять продиктованное, реагировать на клавишу Esc и читать заголовок окна, которое вы прикрепляете.",
  "Koncluí; dikte ettiğin metni yapıştırmak, Esc tuşunu algılamak ve eklediğin pencerenin başlığını okumak için Erişilebilirlik izni ister.",
  "Koncluí memerlukan Aksesibilitas untuk menempelkan hasil dikte, mendeteksi tombol Esc, dan membaca judul jendela yang kamu lampirkan.",
  "يحتاج Koncluí إلى إذن إمكانية الوصول للصق ما تُمليه، والتقاط مفتاح Esc، وقراءة عنوان النافذة التي ترفقها.",
  "আপনি যা ডিক্টেট করেন তা পেস্ট করতে, Esc কী শুনতে এবং আপনার সংযুক্ত করা উইন্ডোর শিরোনাম পড়তে Koncluí-র অ্যাক্সেসিবিলিটি দরকার।",
  "आप जो डिक्टेट करते हैं उसे पेस्ट करने, Esc कुंजी सुनने और आपके जोड़े गए विंडो का शीर्षक पढ़ने के लिए Koncluí को एक्सेसिबिलिटी चाहिए।",
  "Koncluí ต้องใช้การช่วยการเข้าถึงเพื่อวางข้อความที่คุณป้อนด้วยเสียง รับรู้ปุ่ม Esc และอ่านชื่อหน้าต่างที่คุณแนบ",
  "Koncluí 需要“辅助功能”权限，用来粘贴你听写的内容、检测 Esc 键，以及读取你附加的窗口的标题。",
  "Koncluí 需要「輔助使用」權限，用來貼上你聽寫的內容、偵測 Esc 鍵，以及讀取你附加的視窗標題。")

u("NSAppleEventsUsageDescription",
  "Koncluí controls other apps only when you ask: it brings a terminal forward, prepares or sends an email, plays Music and Spotify, and reads the address of the browser tab you attach.",
  "O Koncluí só controla outros apps quando você pede: traz um terminal para a frente, prepara ou envia um e-mail, controla o Música e o Spotify e lê o endereço da aba do navegador que você anexa.",
  "Koncluí solo controla otras apps cuando se lo pides: trae un terminal al frente, prepara o envía un correo, controla Música y Spotify y lee la dirección de la pestaña del navegador que adjuntas.",
  "Koncluí ne pilote d'autres apps que sur ta demande : il passe un terminal au premier plan, prépare ou envoie un e-mail, pilote Musique et Spotify et lit l'adresse de l'onglet du navigateur que tu joins.",
  "Koncluí steuert andere Apps nur auf deine Anweisung: Es holt ein Terminal nach vorn, bereitet E-Mails vor oder sendet sie, steuert Musik und Spotify und liest die Adresse des Browser-Tabs, den du anhängst.",
  "Koncluí управляет другими приложениями только по вашей просьбе: выводит терминал на передний план, готовит или отправляет письмо, управляет Музыкой и Spotify и читает адрес вкладки браузера, которую вы прикрепляете.",
  "Koncluí diğer uygulamaları yalnızca sen istediğinde yönetir: bir terminali öne getirir, e-posta hazırlar veya gönderir, Müzik ve Spotify'ı kontrol eder, eklediğin tarayıcı sekmesinin adresini okur.",
  "Koncluí hanya mengendalikan app lain saat kamu memintanya: membawa terminal ke depan, menyiapkan atau mengirim email, mengendalikan Musik dan Spotify, dan membaca alamat tab browser yang kamu lampirkan.",
  "يتحكم Koncluí في التطبيقات الأخرى فقط عندما تطلب ذلك: يُظهر الطرفية في المقدمة، ويجهّز بريدًا إلكترونيًا أو يرسله، ويتحكم في الموسيقى وSpotify، ويقرأ عنوان تبويب المتصفح الذي ترفقه.",
  "আপনি বললেই শুধু Koncluí অন্য অ্যাপ নিয়ন্ত্রণ করে: টার্মিনালকে সামনে আনে, ইমেইল তৈরি বা পাঠায়, Music ও Spotify চালায় এবং আপনার সংযুক্ত করা ব্রাউজার ট্যাবের ঠিকানা পড়ে।",
  "Koncluí दूसरे ऐप सिर्फ़ तब चलाता है जब आप कहते हैं: टर्मिनल को आगे लाना, ईमेल तैयार करना या भेजना, Music और Spotify चलाना, और आपके जोड़े गए ब्राउज़र टैब का पता पढ़ना।",
  "Koncluí ควบคุมแอปอื่นเฉพาะเมื่อคุณสั่ง: นำเทอร์มินัลมาไว้ด้านหน้า เตรียมหรือส่งอีเมล ควบคุม Music และ Spotify และอ่านที่อยู่ของแท็บเบราว์เซอร์ที่คุณแนบ",
  "只有在你提出要求时，Koncluí 才会控制其他 App：把终端调到前面、准备或发送邮件、控制“音乐”和 Spotify，以及读取你附加的浏览器标签页的地址。",
  "只有在你提出要求時，Koncluí 才會控制其他 App：把終端機帶到最前面、準備或傳送郵件、控制「音樂」和 Spotify，以及讀取你附加的瀏覽器分頁網址。")

u("NSContactsUsageDescription",
  "Koncluí looks up an email address when you ask it, by voice, to prepare an email.",
  "O Koncluí procura um endereço de e-mail quando você pede, por voz, para preparar um e-mail.",
  "Koncluí busca una dirección de correo cuando le pides, por voz, que prepare un correo.",
  "Koncluí cherche une adresse e-mail quand tu lui demandes, à la voix, de préparer un e-mail.",
  "Koncluí sucht eine E-Mail-Adresse heraus, wenn du per Sprache darum bittest, eine E-Mail vorzubereiten.",
  "Koncluí ищет адрес электронной почты, когда вы голосом просите подготовить письмо.",
  "Koncluí, sesle bir e-posta hazırlamasını istediğinde bir e-posta adresi arar.",
  "Koncluí mencari alamat email saat kamu memintanya, lewat suara, menyiapkan email.",
  "يبحث Koncluí عن عنوان بريد إلكتروني عندما تطلب منه، بالصوت، تجهيز رسالة بريد.",
  "আপনি ভয়েসে ইমেইল তৈরি করতে বললে Koncluí একটি ইমেইল ঠিকানা খুঁজে দেখে।",
  "जब आप आवाज़ से ईमेल तैयार करने को कहते हैं, तब Koncluí एक ईमेल पता खोजता है।",
  "Koncluí ค้นหาที่อยู่อีเมลเมื่อคุณสั่งด้วยเสียงให้เตรียมอีเมล",
  "当你用语音让 Koncluí 准备邮件时，它会查找对应的电子邮件地址。",
  "當你用語音請 Koncluí 準備郵件時，它會查詢對應的電子郵件地址。")

u("NSFocusStatusUsageDescription",
  "Koncluí stays quiet about new WhatsApp messages while a Focus is on.",
  "O Koncluí fica quieto com as novas mensagens do WhatsApp enquanto um Foco está ligado.",
  "Koncluí no avisa de mensajes nuevos de WhatsApp mientras hay un modo de concentración activo.",
  "Koncluí reste discret sur les nouveaux messages WhatsApp pendant qu'une Concentration est active.",
  "Koncluí bleibt bei neuen WhatsApp-Nachrichten still, solange ein Fokus aktiv ist.",
  "Koncluí не сообщает о новых сообщениях WhatsApp, пока включён режим фокусировки.",
  "Bir Odak açıkken Koncluí yeni WhatsApp mesajlarında sessiz kalır.",
  "Koncluí tidak memberi tahu pesan WhatsApp baru selama Fokus aktif.",
  "يظل Koncluí هادئًا حيال رسائل WhatsApp الجديدة أثناء تفعيل وضع التركيز.",
  "ফোকাস চালু থাকলে Koncluí নতুন WhatsApp বার্তা নিয়ে চুপ থাকে।",
  "फ़ोकस चालू रहने पर Koncluí नए WhatsApp संदेशों के बारे में शांत रहता है।",
  "Koncluí จะไม่แจ้งข้อความ WhatsApp ใหม่ขณะที่เปิดโฟกัสอยู่",
  "专注模式开启期间，Koncluí 不会提示新的 WhatsApp 消息。",
  "專注模式開啟期間，Koncluí 不會提示新的 WhatsApp 訊息。")

USAGE_KOJA = {
    "NSAccessibilityUsageDescription": {
        "ko": "Koncluí가 받아쓴 내용을 붙여넣고 Esc 키를 감지하며, 첨부한 윈도우의 제목을 읽으려면 손쉬운 사용 권한이 필요합니다.",
        "ja": "Koncluí が音声入力した内容をペーストし、Esc キーを検知して、添付したウインドウのタイトルを読み取るには、アクセシビリティの許可が必要です。",
    },
    "NSAppleEventsUsageDescription": {
        "ko": "요청한 경우에만 Koncluí가 다른 앱을 제어합니다. 터미널을 앞으로 가져오고, 이메일을 작성하거나 보내고, 음악과 Spotify를 재생하며, 첨부한 브라우저 탭의 주소를 읽습니다.",
        "ja": "Koncluí がほかのアプリを操作するのは、依頼された場合のみです。ターミナルを前面に表示し、メールを作成または送信し、「ミュージック」と Spotify を再生して、添付したブラウザタブのアドレスを読み取ります。",
    },
    "NSAudioCaptureUsageDescription": {
        "ko": "통화 메모를 작성하는 동안에만 Mac에서 재생되는 소리를 녹음하여 상대방이 말한 내용을 기록합니다.",
        "ja": "通話のメモを取っている間のみ、Mac で再生される音声を録音し、相手の発言を書き留めます。",
    },
    "NSContactsUsageDescription": {
        "ko": "음성으로 이메일 작성을 요청하면 Koncluí가 이메일 주소를 검색합니다.",
        "ja": "音声でメールの作成を頼むと、Koncluí はメールアドレスを検索します。",
    },
    "NSFocusStatusUsageDescription": {
        "ko": "집중 모드가 켜져 있는 동안 Koncluí는 새 WhatsApp 메시지를 알리지 않습니다.",
        "ja": "集中モード中、Koncluí は新しい WhatsApp メッセージを通知しません。",
    },
    "NSMicrophoneUsageDescription": {
        "ko": "받아쓰기, ‘OK Koru’라고 말하기 또는 통화 메모를 요청할 때 Koncluí가 마이크를 사용합니다.",
        "ja": "音声入力、「OK Koru」と話しかける操作、または通話メモを頼む操作で、Koncluí はマイクを使用します。",
    },
    "NSSpeechRecognitionUsageDescription": {
        "ko": "받아쓰기, ‘OK Koru’라고 말하기 또는 통화 메모를 작성할 때 Koncluí가 음성을 텍스트로 변환합니다. 음성 인식은 Mac에서 처리되며, 가능한 경우 기기 내에서 이루어집니다.",
        "ja": "音声入力、「OK Koru」と話しかける操作、または通話のメモを取る操作で、Koncluí は音声をテキストに変換します。音声認識は Mac で行い、可能な場合はデバイス上で処理します。",
    },
}
if set(USAGE_KOJA) != set(USAGE):
    raise ValueError("Every permission prompt must have Korean and Japanese copy")
for _key, _translations in USAGE_KOJA.items():
    if set(_translations) != {"ko", "ja"}:
        raise ValueError(f"{_key}: expected Korean and Japanese permission copy")
    USAGE[_key].update(_translations)

# project.yml writes the English into Info.plist; the 16 languages come from InfoPlist.xcstrings (a resource of the Mac
# target, inserted below). The old lines are what project.yml holds after rebrand.py's brand pass.
_PROJECT = "NotchBuddy/project.yml"
for _key, _old in (
        ("NSAppleEventsUsageDescription", "Pour sauter au terminal, envoyer des mails et piloter Musique et Spotify."),
        ("NSMicrophoneUsageDescription", "Koncluí uses the microphone when you dictate, and to note your calls when you ask it to."),
        ("NSSpeechRecognitionUsageDescription", "Koncluí turns your voice into the text of a chat message."),
        ("NSAccessibilityUsageDescription", "Pour lire le titre de la fenêtre active et l'attacher comme contexte.")):
    FIXED.append((_PROJECT, f'{_key}: "{_old}"', f'{_key}: "{USAGE[_key]["en"]}"'))

INSERTS.append((
    _PROJECT,
    "      # What's new after an update, once in the notch (WhatsNewViews.swift; GitHub build)\n",
    "      # Koncluí: the permission prompts in all 16 languages (Info.plist keeps the English), copy table in\n"
    "      # scripts/konclui/rebrand_copy_data.py\n"
    "      - path: Resources/InfoPlist.xcstrings\n"
    "        buildPhase: resources\n"))


# ---------------------------------------------------------------------------------------------
# Names (A1-11, A1-33, A1-19, A3-21). One meaning per word:
#   "Ajustes do ditado" = the dictation page of the window     (was "Ajustes" / "Koncluí Flow → Ajustes")
#   "Ajustes do Sistema" = macOS System Settings                 (was "Ajustes" / "Configurações" on the pill of the mic prompt)
#   a notch page is named by its own name ("em Chat", "em Integrações"); the window is "Koncluí", never "Koncluí Flow".

r("hub.page.settings", "Settings",
  "Dictation settings", "Ajustes do ditado", "Ajustes del dictado", "Réglages de la dictée", "Diktat-Einstellungen",
  "Настройки диктовки", "Dikte ayarları", "Pengaturan dikte", "إعدادات الإملاء", "ডিক্টেশন সেটিংস", "डिक्टेशन सेटिंग्स",
  "การตั้งค่าการป้อนด้วยเสียง", "听写设置", "聽寫設定")

r("hub.open-settings", "Open Settings",
  "Open Chat", "Abrir Chat", "Abrir Chat", "Ouvrir Chat", "Chat öffnen", "Открыть Чат", "Sohbeti aç", "Buka Obrolan",
  "فتح الدردشة", "চ্যাট খুলুন", "चैट खोलें", "เปิดแชต", "打开聊天", "開啟聊天")

r("hub.open", "Open Koncluí Flow",
  "Open dictation settings", "Abrir os ajustes do ditado", "Abrir los ajustes del dictado", "Ouvrir les réglages de la dictée",
  "Diktat-Einstellungen öffnen", "Открыть настройки диктовки", "Dikte ayarlarını aç", "Buka pengaturan dikte",
  "فتح إعدادات الإملاء", "ডিক্টেশন সেটিংস খুলুন", "डिक्टेशन सेटिंग्स खोलें", "เปิดการตั้งค่าการป้อนด้วยเสียง",
  "打开听写设置", "開啟聽寫設定")

r("hub.menu", "Koncluí Flow…",
  "Open Koncluí…", "Abrir o Koncluí…", "Abrir Koncluí…", "Ouvrir Koncluí…", "Koncluí öffnen…", "Открыть Koncluí…",
  "Koncluí'yu aç…", "Buka Koncluí…", "فتح Koncluí…", "Koncluí খুলুন…", "Koncluí खोलें…", "เปิด Koncluí…",
  "打开 Koncluí…", "開啟 Koncluí…")

r("flow.title", "Flow dictation",
  "Dictation", "Ditado", "Dictado", "Dictée", "Diktat", "Диктовка", "Dikte", "Dikte", "الإملاء", "ডিক্টেশন", "डिक्टेशन",
  "การป้อนข้อความด้วยเสียง", "听写", "聽寫")

# The microphone prompt's button opens macOS's System Settings, not Koncluí's.
r("flow.ann.settings", "Settings",
  "System Settings", "Ajustes do Sistema", "Ajustes del Sistema", "Réglages Système", "Systemeinstellungen",
  "Системные настройки", "Sistem Ayarları", "Pengaturan Sistem", "إعدادات النظام", "সিস্টেম সেটিংস", "सिस्टम सेटिंग्स",
  "การตั้งค่าระบบ", "系统设置", "系統設定")

s("notes.error.models",
  ("Koncluí Flow → Settings", "Dictation settings › Recognition"),
  ("Koncluí Flow → Ajustes", "Ajustes do ditado › Reconhecimento"),
  ("Koncluí Flow → Ajustes", "Ajustes del dictado › Reconocimiento"),
  ("Koncluí Flow → Réglages", "Réglages de la dictée › Reconnaissance"),
  ("Koncluí Flow → Einstellungen", "Diktat-Einstellungen › Erkennung"),
  ("Koncluí Flow → Настройки", "Настройки диктовки › Распознавание"),
  ("Koncluí Flow → Ayarlar", "Dikte ayarları › Tanıma"),
  ("Koncluí Flow → Pengaturan", "Pengaturan dikte › Pengenalan"),
  ("Koncluí Flow ← الإعدادات", "إعدادات الإملاء ‹ التعرّف"),
  ("Koncluí Flow → সেটিংস", "ডিক্টেশন সেটিংস › রিকগনিশন"),
  ("Koncluí Flow → सेटिंग्स", "डिक्टेशन सेटिंग्स › पहचान"),
  ("Koncluí Flow → การตั้งค่า", "การตั้งค่าการป้อนด้วยเสียง › การรู้จำเสียง"),
  ("Koncluí Flow →“设置”", "“听写设置”›“识别”"),
  ("Koncluí Flow → 設定", "聽寫設定 › 語音辨識"))

s("hub.history-off",
  ("Settings → Privacy", "Dictation settings › Privacy"),
  [("Ative-o em Ajustes → Privacidade", "Ligue em Ajustes do ditado › Privacidade")],
  ("Ajustes → Privacidad", "Ajustes del dictado › Privacidad"),
  ("Réglages → Confidentialité", "Réglages de la dictée › Confidentialité"),
  ("Einstellungen → Datenschutz", "Diktat-Einstellungen › Datenschutz"),
  ("Настройки → Конфиденциальность", "Настройки диктовки › Конфиденциальность"),
  ("Ayarlar → Gizlilik", "Dikte ayarları › Gizlilik"),
  ("Pengaturan → Privasi", "Pengaturan dikte › Privasi"),
  ("الإعدادات ← الخصوصية", "إعدادات الإملاء ‹ الخصوصية"),
  ("সেটিংস → গোপনীয়তা", "ডিক্টেশন সেটিংস › গোপনীয়তা"),
  ("सेटिंग्स → गोपनीयता", "डिक्टेशन सेटिंग्स › गोपनीयता"),
  ("การตั้งค่า → ความเป็นส่วนตัว", "การตั้งค่าการป้อนด้วยเสียง › ความเป็นส่วนตัว"),
  ("“设置”→“隐私”", "“听写设置”›“隐私”"),
  ("設定 → 隱私權", "聽寫設定 › 隱私權"))

# Where a key goes: Chat is a page of the window, so the sentence names the page, not "Settings → Chat".
r("hub.cleanup-key", "The clean-up uses your Claude key. Add it in Settings → Chat.",
  "The clean-up uses Claude. Add your Claude key in Chat.",
  "A limpeza usa o Claude. Adicione a chave do Claude em Chat.",
  "La limpieza usa Claude. Añade tu clave de Claude en Chat.",
  "Le nettoyage utilise Claude. Ajoute ta clé Claude dans Chat.",
  "Die Überarbeitung nutzt Claude. Füge deinen Claude-Schlüssel unter Chat hinzu.",
  "Для чистки нужен Claude. Добавьте ключ Claude на странице Чат.",
  "Düzenleme Claude'u kullanır. Claude anahtarını Sohbet sayfasından ekle.",
  "Perapian memakai Claude. Tambahkan kunci Claude di Chat.",
  "يستخدم التنقيح Claude. أضف مفتاح Claude في صفحة الدردشة.",
  "পরিষ্কার করতে Claude লাগে। চ্যাট পেজে আপনার Claude কী যোগ করুন।",
  "सफ़ाई Claude से होती है। चैट पेज में अपनी Claude कुंजी जोड़ें।",
  "การปรับข้อความใช้ Claude เพิ่มคีย์ Claude ของคุณที่หน้าแชต",
  "整理会使用 Claude。请在“聊天”页面添加你的 Claude 密钥。",
  "文字整理使用 Claude。請在「聊天」頁面新增你的 Claude 金鑰。")

s("notes.engine-detail",
  ("key from Settings → Chat", "key from Chat"),
  ("chave de Ajustes → Chat", "chave de Chat"),
  ("clave de Ajustes → Chat", "clave de Chat"),
  ("clé de Réglages → Chat", "clé de Chat"),
  ("Schlüssel aus Einstellungen → Chat", "Schlüssel aus Chat"),
  ("ключом из Настройки → Чат", "ключом со страницы Чат"),
  ("Ayarlar → Sohbet bölümündeki", "Sohbet sayfasındaki"),
  ("Pengaturan → Obrolan", "Chat"),
  ("من الإعدادات ← الدردشة", "من صفحة الدردشة"),
  ("সেটিংস → চ্যাট-এর কী", "চ্যাট পেজের কী"),
  ("सेटिंग्स → चैट वाली", "चैट पेज वाली"),
  ("จาก การตั้งค่า → แชต", "จากหน้าแชต"),
  ("“设置”→“聊天”中的密钥", "“聊天”页面中的密钥"),
  ("「設定 → 聊天」中的金鑰", "「聊天」頁面中的金鑰"))

s("crypto.no-coins",
  ("Settings → Integrations", "Integrations"),
  ("Ajustes → Integrações", "Integrações"),
  ("Ajustes → Integraciones", "Integraciones"),
  ("Réglages → Intégrations", "Intégrations"),
  ("Einstellungen → Integrationen", "Integrationen"),
  ("Настройки → Интеграции", "Интеграции"),
  ("Ayarlar → Entegrasyonlar bölümünden", "Entegrasyonlar sayfasından"),
  ("Pengaturan → Integrasi", "Integrasi"),
  ("الإعدادات ← التكاملات", "التكاملات"),
  ("সেটিংস → ইন্টিগ্রেশনে", "ইন্টিগ্রেশন পেজে"),
  ("सेटिंग्स → इंटीग्रेशन में", "इंटीग्रेशन पेज में"),
  ("การตั้งค่า → การเชื่อมต่อ", "การเชื่อมต่อ"),
  ("“设置 → 集成”中", "“集成”页面中"),
  ("「設定 → 整合」", "「整合」頁面"))

s("portfolio.no-accounts",
  ("Settings → Integrations", "Integrations"),
  ("Ajustes → Integrações", "Integrações"),
  ("Ajustes → Integraciones", "Integraciones"),
  ("Réglages → Intégrations", "Intégrations"),
  ("Einstellungen → Integrationen", "Integrationen"),
  None,
  ("Ayarlar → Entegrasyonlar bölümünden", "Entegrasyonlar sayfasından"),
  ("Pengaturan → Integrasi", "Integrasi"),
  ("الإعدادات → التكاملات", "التكاملات"),
  ("সেটিংস → ইন্টিগ্রেশনে", "ইন্টিগ্রেশন পেজে"),
  ("सेटिंग्स → एकीकरण में", "इंटीग्रेशन पेज में"),
  ("การตั้งค่า → การเชื่อมต่อ", "การเชื่อมต่อ"),
  ("设置 → 集成中", "“集成”页面中"),
  ("「設定 → 整合」", "「整合」頁面"))

s("konclui.voice.claude.missing",
  ("in Settings → Chat", "in Chat"),
  ("em Ajustes → Chat", "em Chat"),
  ("en Ajustes → Chat", "en Chat"),
  ("dans Réglages → Chat", "dans Chat"),
  ("unter Einstellungen → Chat", "unter Chat"),
  ("в Настройки → Чат", "на странице Чат"),
  ("Ayarlar → Sohbet bölümüne", "Sohbet sayfasına"),
  ("Pengaturan → Chat", "Chat"),
  ("في الإعدادات ← الدردشة", "في صفحة الدردشة"),
  ("সেটিংস → চ্যাটে", "চ্যাট পেজে"),
  ("सेटिंग्स → चैट में", "चैट पेज में"),
  ("ได้ที่ การตั้งค่า → แชต", "ได้ที่หน้าแชต"),
  ("在设置 → 聊天中", "在“聊天”页面中"),
  ("在「設定 → 聊天」中", "在「聊天」頁面中"))

r("konclui.voice.claude.open-chat", "Open Chat settings",
  "Open Chat", "Abrir Chat", "Abrir Chat", "Ouvrir Chat", "Chat öffnen", "Открыть Чат", "Sohbeti aç", "Buka Chat",
  "فتح الدردشة", "চ্যাট খুলুন", "चैट खोलें", "เปิดแชต", "打开聊天", "開啟聊天")

# WhatsApp status lines name the page, and de/th/tr never had them.
r("whatsapp.status.needs-qr", "Scan the QR code in Settings",
  "Scan the QR code in Integrations", "Escaneie o QR code em Integrações", "Escanea el código QR en Integraciones",
  "Scanne le QR code dans Intégrations", "Scanne den QR-Code unter Integrationen", "Отсканируйте QR-код в Интеграциях",
  "QR kodunu Entegrasyonlar sayfasında tara", "Pindai kode QR di Integrasi", "امسح رمز QR في صفحة التكاملات",
  "ইন্টিগ্রেশন পেজে QR কোড স্ক্যান করুন", "इंटीग्रेशन पेज में QR कोड स्कैन करें", "สแกนคิวอาร์โค้ดที่หน้าการเชื่อมต่อ",
  "请在“集成”页面扫描二维码", "請在「整合」頁面掃描 QR 碼")

r("whatsapp.status.off", "Turned off in Settings",
  "Turned off in Integrations", "Desligado em Integrações", "Desactivado en Integraciones", "Désactivé dans Intégrations",
  "In Integrationen ausgeschaltet", "Выключено в Интеграциях", "Entegrasyonlar sayfasında kapalı", "Dimatikan di Integrasi",
  "متوقف في صفحة التكاملات", "ইন্টিগ্রেশন পেজে বন্ধ", "इंटीग्रेशन पेज में बंद है", "ปิดอยู่ที่หน้าการเชื่อมต่อ",
  "已在“集成”页面中关闭", "已在「整合」頁面中關閉")

# The app's own settings (the menu bar) are "Ajustes…", the way Apple writes it in pt-BR.
r("Settings…", "Settings…",
  None, "Ajustes…", None, None, None, None, None, None, None, None, None, None, None, None)
r("Open Settings…", "Open Settings…",
  None, "Abrir os ajustes…", None, None, None, None, None, None, None, None, None, None, None, None)
r("settings.window.title", "Settings — Koncluí",
  "Koncluí Settings", "Ajustes do Koncluí", "Ajustes de Koncluí", "Réglages de Koncluí", "Koncluí-Einstellungen",
  "Настройки Koncluí", "Koncluí Ayarları", "Pengaturan Koncluí", "إعدادات Koncluí", "Koncluí সেটিংস", "Koncluí सेटिंग्स",
  "การตั้งค่า Koncluí", "Koncluí 设置", "Koncluí 設定")

PATHS += ["flow.accessibility", "capture.permission", "flow.fn-help", "notes.error.mic", "voice.mac-voices-help",
          "No speech recognition model available on this device. Install one in System Settings → Keyboard → Dictation."]
s("konclui.voice.permission.denied", None,
  ("Ajustes do Sistema → Privacidade e Segurança", "Ajustes do Sistema › Privacidade e Segurança"),
  ("Ajustes del Sistema → Privacidad y seguridad", "Ajustes del Sistema › Privacidad y seguridad"),
  ("Réglages Système → Confidentialité et sécurité", "Réglages Système › Confidentialité et sécurité"),
  ("Systemeinstellungen → Datenschutz & Sicherheit", "Systemeinstellungen › Datenschutz & Sicherheit"),
  ("Системных настройках → Конфиденциальность и безопасность", "Системных настройках › Конфиденциальность и безопасность"),
  ("Sistem Ayarları → Gizlilik ve Güvenlik", "Sistem Ayarları › Gizlilik ve Güvenlik"),
  ("Pengaturan Sistem → Privasi & Keamanan", "Pengaturan Sistem › Privasi & Keamanan"),
  ("إعدادات النظام ← الخصوصية والأمن", "إعدادات النظام ‹ الخصوصية والأمن"),
  ("সিস্টেম সেটিংস → গোপনীয়তা ও নিরাপত্তায়", "সিস্টেম সেটিংস › গোপনীয়তা ও নিরাপত্তায়"),
  ("सिस्टम सेटिंग्स → गोपनीयता और सुरक्षा में", "सिस्टम सेटिंग्स › गोपनीयता और सुरक्षा में"),
  ("การตั้งค่าระบบ → ความเป็นส่วนตัวและความปลอดภัย", "การตั้งค่าระบบ › ความเป็นส่วนตัวและความปลอดภัย"),
  ("“系统设置 → 隐私与安全性”", "“系统设置 › 隐私与安全性”"),
  ("「系統設定 → 隱私權與安全性」", "「系統設定 › 隱私權與安全性」"))


# ---------------------------------------------------------------------------------------------
# The notch is "notch" (A1-18, A3-21); shortcut labels read as actions, not as code (A1-36, A1-37, A1-43).

r("shortcut.group.island", "Notch shortcuts — active when the notch is in front",
  "Notch shortcuts (when the notch is open)", "Atalhos do notch (com o notch aberto)", "Atajos del notch (con el notch abierto)",
  "Raccourcis du notch (quand il est ouvert)", "Notch-Tastenkombinationen (bei geöffneter Notch)",
  "Сочетания нотча (когда он открыт)", "Ada kısayolları (ada açıkken)", "Pintasan notch (saat notch terbuka)",
  "اختصارات النوتش (عند فتح النوتش)", "নচ শর্টকাট (নচ খোলা থাকলে)", "नॉच शॉर्टकट (नॉच खुला होने पर)",
  "ปุ่มลัดของ Notch (เมื่อเปิด Notch อยู่)", "刘海快捷键（刘海展开时）", "瀏海快捷鍵（瀏海展開時）")

r("shortcut.group.global", "Global shortcuts — active from any app",
  "Global shortcuts (from any app)", "Atalhos globais (em qualquer app)", "Atajos globales (desde cualquier app)",
  "Raccourcis globaux (depuis n'importe quelle app)", "Globale Tastenkombinationen (in jeder App)",
  "Глобальные сочетания (из любого приложения)", "Genel kısayollar (her uygulamada)", "Pintasan global (dari app mana pun)",
  "اختصارات عامة (من أي تطبيق)", "গ্লোবাল শর্টকাট (যেকোনো অ্যাপ থেকে)", "ग्लोबल शॉर्टकट (किसी भी ऐप से)",
  "ปุ่มลัดทั่วระบบ (ใช้ได้จากทุกแอป)", "全局快捷键（在任何应用中）", "全域快捷鍵（在任何應用程式中）")

r("shortcut.open-close-island", "Open / close notch",
  "Open or close the notch", "Abrir ou fechar o notch", "Abrir o cerrar el notch", "Ouvrir ou fermer le notch",
  "Notch öffnen oder schließen", "Открыть или закрыть нотч", "Adayı aç veya kapat", "Buka atau tutup notch",
  "فتح النوتش أو إغلاقه", "নচ খুলুন বা বন্ধ করুন", "नॉच खोलें या बंद करें", "เปิดหรือปิด Notch",
  "打开或关闭刘海", "開啟或關閉瀏海")

r("shortcut.island.pin", "Pin / unpin notch",
  "Pin or unpin the notch", "Fixar ou soltar o notch", "Fijar o soltar el notch", "Épingler ou désépingler le notch",
  "Notch anheften oder lösen", "Закрепить или открепить нотч", "Adayı sabitle veya serbest bırak",
  "Sematkan atau lepas notch", "تثبيت النوتش أو إلغاء تثبيته", "নচ পিন বা আনপিন করুন", "नॉच पिन या अनपिन करें",
  "ปักหมุดหรือถอนหมุด Notch", "固定或取消固定刘海", "固定或取消固定瀏海")

r("shortcut.island.close", "Close notch (if not pinned)",
  "Close the notch (if not pinned)", "Fechar o notch (se não estiver fixado)", "Cerrar el notch (si no está fijado)",
  "Fermer le notch (s'il n'est pas épinglé)", "Notch schließen (falls nicht angeheftet)",
  "Закрыть нотч (если не закреплён)", "Adayı kapat (sabitlenmemişse)", "Tutup notch (jika tidak disematkan)",
  "إغلاق النوتش (إذا لم يكن مثبّتًا)", "নচ বন্ধ করুন (পিন না থাকলে)", "नॉच बंद करें (पिन न हो तो)",
  "ปิด Notch (หากไม่ได้ปักหมุด)", "关闭刘海（如未固定）", "關閉瀏海（未固定時）")

r("shortcut.island.next-prev", "Next / previous tab",
  "Next or previous tab", "Aba seguinte ou anterior", "Pestaña siguiente o anterior", "Onglet suivant ou précédent",
  "Nächster oder vorheriger Tab", "Следующая или предыдущая вкладка", "Sonraki veya önceki sekme",
  "Tab berikutnya atau sebelumnya", "التبويب التالي أو السابق", "পরের বা আগের ট্যাব", "अगला या पिछला टैब",
  "แท็บถัดไปหรือก่อนหน้า", "下一个或上一个标签", "下一個或上一個標籤")

r("shortcut.mute-toggle", "Mute / unmute sounds",
  "Mute or unmute sounds", "Ligar ou desligar os sons", "Silenciar o activar los sonidos", "Couper ou rétablir les sons",
  "Klänge stummschalten oder einschalten", "Выключить или включить звук", "Sesleri kapat veya aç",
  "Bisukan atau aktifkan suara", "كتم الأصوات أو إلغاء كتمها", "শব্দ মিউট বা আনমিউট করুন", "ध्वनि म्यूट या अनम्यूट करें",
  "ปิดหรือเปิดเสียง", "静音或取消静音", "靜音或取消靜音")

r("shortcut.desktop-toggle", "Koru to desktop on/off",
  "Show or hide Koru on the desktop", "Mostrar ou esconder a Koru na área de trabalho",
  "Mostrar u ocultar Koru en el escritorio", "Afficher ou masquer Koru sur le bureau",
  "Koru auf dem Desktop ein- oder ausblenden", "Показать или скрыть Koru на рабочем столе",
  "Koru'yu masaüstünde göster veya gizle", "Tampilkan atau sembunyikan Koru di desktop",
  "إظهار Koru على سطح المكتب أو إخفاء Koru", "ডেস্কটপে Koru দেখান বা লুকান", "डेस्कटॉप पर Koru दिखाएं या छिपाएं",
  "แสดงหรือซ่อน Koru บนเดสก์ท็อป", "在桌面显示或隐藏 Koru", "在桌面顯示或隱藏 Koru")

r("shortcut.wardrobe", "Open / close wardrobe",
  "Open or close the wardrobe", "Abrir ou fechar o guarda-roupa", "Abrir o cerrar el guardarropa",
  "Ouvrir ou fermer la garde-robe", "Garderobe öffnen oder schließen", "Открыть или закрыть гардероб",
  "Gardırobu aç veya kapat", "Buka atau tutup lemari", "فتح خزانة الملابس أو إغلاقها",
  "পোশাকের আলমারি খুলুন বা বন্ধ করুন", "वार्डरोब खोलें या बंद करें", "เปิดหรือปิดชุดของ Koru",
  "打开或关闭衣橱", "開啟或關閉衣櫥")

r("Show island with shortcut", "Show island with shortcut",
  "Open the notch with a shortcut", "Abrir o notch com um atalho", "Abrir el notch con un atajo",
  "Ouvrir le notch avec un raccourci", "Notch per Tastenkombination öffnen", "Открывать нотч сочетанием клавиш",
  "Adayı kısayolla aç", "Buka notch dengan pintasan", "فتح النوتش باختصار", "শর্টকাট দিয়ে নচ খুলুন",
  "शॉर्टकट से नॉच खोलें", "เปิด Notch ด้วยปุ่มลัด", "用快捷键打开刘海", "使用快捷鍵開啟瀏海")

r("presses this → island opens", "presses this → island opens",
  "This shortcut opens the notch.", "Esse atalho abre o notch.", "Este atajo abre el notch.",
  "Ce raccourci ouvre le notch.", "Diese Tastenkombination öffnet die Notch.", "Это сочетание открывает нотч.",
  "Bu kısayol adayı açar.", "Pintasan ini membuka notch.", "يفتح هذا الاختصار النوتش.", "এই শর্টকাট নচ খোলে।",
  "यह शॉर्टकट नॉच खोलता है।", "ปุ่มลัดนี้จะเปิด Notch", "此快捷键会打开刘海。", "此快捷鍵會開啟瀏海。")

r("Hovering the island opens it; it folds again shortly after the pointer leaves. Click inside to keep it open.",
  "Hovering the island opens it; it folds again shortly after the pointer leaves. Click inside to keep it open.",
  "Hovering the notch opens it; it folds again shortly after the pointer leaves. Click inside to keep it open.",
  "Passar o cursor pelo notch o abre; ele se fecha logo depois que o cursor sai. Clique dentro para mantê-lo aberto.",
  "Pasar el cursor por el notch lo abre; se pliega poco después de que el cursor salga. Haz clic dentro para dejarlo abierto.",
  "Survoler le notch l'ouvre ; il se replie peu après que le pointeur le quitte. Cliquez dedans pour le garder ouvert.",
  "Die Notch öffnet sich, wenn du den Mauszeiger darüber bewegst, und klappt kurz nach dem Verlassen wieder zu. Klicke hinein, damit sie geöffnet bleibt.",
  "Наведение указателя открывает нотч; он сворачивается вскоре после того, как указатель уходит. Щёлкните внутри, чтобы он остался открытым.",
  None,
  "Mengarahkan kursor ke notch akan membukanya; notch menutup lagi sesaat setelah kursor pergi. Klik di dalamnya agar tetap terbuka.",
  "يفتح التمرير فوق النوتش ويُطوى بعد مغادرة المؤشر بقليل. انقر داخله لإبقائه مفتوحًا.",
  "নচের উপর পয়েন্টার রাখলে সেটি খোলে; পয়েন্টার সরালে একটু পরে আবার গুটিয়ে যায়। খোলা রাখতে ভিতরে ক্লিক করুন।",
  "नॉच पर पॉइंटर ले जाने से वह खुलता है; पॉइंटर हटने के कुछ देर बाद फिर सिमट जाता है। खुला रखने के लिए अंदर क्लिक करें।",
  "ชี้เมาส์ที่ Notch เพื่อเปิด Notch จะพับหลังจากเลื่อนเมาส์ออก คลิกด้านในเพื่อเปิดค้างไว้",
  "将指针悬停在刘海上即可打开；指针离开后不久会再次收起。在其中点按可保持打开。",
  "將游標移到瀏海上即可展開；移開後會稍候收合。點一下內部可讓它保持展開。")

r("Applies on next launch", "Applies on next launch",
  None, "Vale quando o Koncluí abrir de novo", None, None, None, None, None, None, None, None, None, None, None, None)

r("update.you-have %@", "You have %@",
  "Installed version: %@", "Versão instalada: %@", "Versión instalada: %@", "Version installée : %@",
  "Installierte Version: %@", "Установленная версия: %@", "Yüklü sürüm: %@", "Versi terpasang: %@",
  "الإصدار المثبّت: %@", "ইনস্টল করা সংস্করণ: %@", "इंस्टॉल किया गया संस्करण: %@", "เวอร์ชันที่ติดตั้ง: %@",
  "已安装版本：%@", "已安裝版本：%@")

r("settings.slots-used %lld", "%lld/4 slots used",
  "%lld of 4 pills on", "%lld de 4 abas ligadas", "%lld de 4 píldoras activas", "%lld pills actives sur 4",
  "%lld von 4 Pills aktiv", "%lld из 4 пилюль включено", "4 araçtan %lld tanesi açık", "%lld dari 4 pil aktif",
  "%lld من 4 حبات مفعّلة", "৪টির মধ্যে %lld পিল চালু", "4 में से %lld पिल चालू", "เปิดแถบ %lld จาก 4",
  "已开启 %lld/4 个胶囊", "已開啟 %lld/4 個標籤")

# A1-19: the floating dictation indicator is not a notch tab.
r("flow.edge", "Where the pill is",
  "Where the dictation pill sits", "Posição do indicador de ditado", "Posición del indicador de dictado",
  "Position de l'indicateur de dictée", None, "Где индикатор диктовки", None, "Posisi indikator dikte",
  "موضع مؤشر الإملاء", "ডিক্টেশন ইন্ডিকেটরের অবস্থান", "डिक्टेशन इंडिकेटर की जगह", "ตำแหน่งตัวบอกการป้อนด้วยเสียง",
  "听写指示器的位置", "聽寫指示器的位置")

# A1-42, A3-24: the Accessibility explanation, short, with the macOS path written once with ›. The advice to remove Koncluí and add
# it again is `konclui.flow.accessibility-stale`, shown by Ajustes do ditado only after macOS once trusted Koncluí.
r("flow.accessibility",
  ("Koncluí can't paste yet, or see Esc: it needs the Accessibility permission. Turn on Koncluí in System Settings → Privacy & Security → Accessibility. If it is already on, remove it with − and add it again: a new build of Koncluí needs it again.",
   # the text this rule wrote before the advice moved to `konclui.flow.accessibility-stale`
   "Koncluí needs the Accessibility permission to paste what you dictate and to hear Esc. Turn it on in System Settings › Privacy & Security › Accessibility. Already on? Remove Koncluí from the list (the minus button) and add it again."),
  "Koncluí needs the Accessibility permission to paste what you dictate and to hear Esc. Turn it on in System Settings › Privacy & Security › Accessibility.",
  "O Koncluí precisa da permissão de Acessibilidade para colar o que você dita e ouvir o Esc. Ative em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade.",
  "Koncluí necesita el permiso de Accesibilidad para pegar lo que dictas y detectar Esc. Actívalo en Ajustes del Sistema › Privacidad y seguridad › Accesibilidad.",
  "Koncluí a besoin de l'autorisation Accessibilité pour coller ce que tu dictes et détecter Échap. Active-la dans Réglages Système › Confidentialité et sécurité › Accessibilité.",
  "Koncluí braucht die Berechtigung für Bedienungshilfen, um Diktiertes einzufügen und Esc zu erkennen. Aktiviere sie unter Systemeinstellungen › Datenschutz & Sicherheit › Bedienungshilfen.",
  "Koncluí нужно разрешение «Универсальный доступ», чтобы вставлять продиктованное и видеть Esc. Включите его в Системных настройках › Конфиденциальность и безопасность › Универсальный доступ.",
  "Koncluí'nun dikte ettiğin metni yapıştırması ve Esc tuşunu algılaması için Erişilebilirlik izni gerekir. Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik bölümünden aç.",
  "Koncluí membutuhkan izin Aksesibilitas untuk menempelkan hasil dikte dan mendeteksi Esc. Aktifkan di Pengaturan Sistem › Privasi & Keamanan › Aksesibilitas.",
  "يحتاج Koncluí إلى إذن تسهيلات الاستخدام للصق ما تُمليه والتقاط مفتاح Esc. فعّله من إعدادات النظام ‹ الخصوصية والأمن ‹ تسهيلات الاستخدام.",
  "আপনি যা ডিক্টেট করেন তা পেস্ট করতে এবং Esc শুনতে Koncluí-র অ্যাক্সেসিবিলিটি অনুমতি দরকার। সিস্টেম সেটিংস › গোপনীয়তা ও নিরাপত্তা › অ্যাক্সেসিবিলিটিতে চালু করুন।",
  "आप जो डिक्टेट करते हैं उसे पेस्ट करने और Esc सुनने के लिए Koncluí को एक्सेसिबिलिटी अनुमति चाहिए। सिस्टम सेटिंग्स › गोपनीयता और सुरक्षा › एक्सेसिबिलिटी में इसे चालू करें।",
  "Koncluí ต้องได้รับอนุญาตด้านการช่วยการเข้าถึงเพื่อวางข้อความที่คุณป้อนด้วยเสียงและรับรู้ปุ่ม Esc เปิดได้ที่ การตั้งค่าระบบ › ความเป็นส่วนตัวและความปลอดภัย › การช่วยการเข้าถึง",
  "Koncluí 需要“辅助功能”权限才能粘贴你听写的内容并识别 Esc。请在“系统设置”›“隐私与安全性”›“辅助功能”中打开。",
  "Koncluí 需要「輔助使用」權限才能貼上你聽寫的內容並偵測 Esc。請在「系統設定 › 隱私權與安全性 › 輔助使用」中開啟。")
PATHS.remove("flow.accessibility")

# A1-32: the updater does not verify a notarization yet (KONCLUI.md, open items), so the footer must not promise it.
r("update.settings.footer",
  "Koncluí looks at its own releases on GitHub a few times a day. An update is installed only after your click, once Apple’s signature and notarization check out.",
  "Koncluí looks for new versions on GitHub a few times a day. Nothing is installed without your click.",
  "O Koncluí procura novas versões no GitHub algumas vezes por dia. Nada é instalado sem o seu clique.",
  "Koncluí busca nuevas versiones en GitHub unas veces al día. No se instala nada sin tu clic.",
  "Koncluí cherche de nouvelles versions sur GitHub quelques fois par jour. Rien n'est installé sans ton clic.",
  "Koncluí sucht ein paar Mal am Tag auf GitHub nach neuen Versionen. Ohne deinen Klick wird nichts installiert.",
  "Koncluí несколько раз в день ищет новые версии на GitHub. Без вашего нажатия ничего не устанавливается.",
  "Koncluí günde birkaç kez GitHub'da yeni sürümlere bakar. Sen tıklamadan hiçbir şey yüklenmez.",
  "Koncluí mencari versi baru di GitHub beberapa kali sehari. Tidak ada yang dipasang tanpa klikmu.",
  "يبحث Koncluí عن إصدارات جديدة على GitHub بضع مرات يوميًا. لا يُثبَّت شيء دون نقرتك.",
  "Koncluí দিনে কয়েকবার GitHub-এ নতুন সংস্করণ খোঁজে। আপনার ক্লিক ছাড়া কিছু ইনস্টল হয় না।",
  "Koncluí दिन में कुछ बार GitHub पर नए संस्करण खोजता है। आपके क्लिक के बिना कुछ इंस्टॉल नहीं होता।",
  "Koncluí จะตรวจหาเวอร์ชันใหม่บน GitHub วันละไม่กี่ครั้ง และจะไม่ติดตั้งอะไรหากคุณไม่คลิก",
  "Koncluí 每天会在 GitHub 上查找几次新版本。没有你的点击，不会安装任何内容。",
  "Koncluí 每天會在 GitHub 上尋找幾次新版本。沒有你的點擊，不會安裝任何內容。")

# A1-08, A2-25: the Voice box title and its text, with the quotes of each language and no dash.
_VOICE_TITLE = ("« OK Koru » — voice wake word", "« OK Koru » — voice wake word")
r("« OK Koru » — voice wake word", _VOICE_TITLE,
  "Wake word “OK Koru”", "Palavra de ativação “OK Koru”", "Palabra de activación «OK Koru»", "Mot d'activation « OK Koru »",
  "Aktivierungswort „OK Koru“", "Слово активации «OK Koru»", "Uyandırma sözcüğü “OK Koru”", "Kata pemicu “OK Koru”",
  "كلمة التنشيط «OK Koru»", "ওয়েক ওয়ার্ড “OK Koru”", "वेक वर्ड “OK Koru”", "คำปลุก “OK Koru”",
  "唤醒词“OK Koru”", "喚醒詞「OK Koru」")

_VOICE_TEXT = ("When enabled, Koncluí listens for the wake word « OK Koru ». Speech recognition runs entirely on-device — no audio or transcript leaves your Mac.",
               "When enabled, Koncluí listens for the wake word « OK Koru ». Speech recognition runs entirely on-device — no audio or transcript leaves your Mac.")
r("When enabled, Koncluí listens for the wake word « OK Koru ». Speech recognition runs entirely on-device — no audio or transcript leaves your Mac.",
  _VOICE_TEXT,
  "When enabled, Koncluí listens for the wake word “OK Koru”. Speech recognition runs entirely on this Mac: no audio or transcript leaves it.",
  "Quando ativado, o Koncluí escuta a palavra de ativação “OK Koru”. O reconhecimento de fala acontece inteiramente neste Mac: nenhum áudio ou transcrição sai dele.",
  "Cuando está activado, Koncluí escucha la palabra de activación «OK Koru». El reconocimiento de voz se ejecuta por completo en este Mac: ningún audio ni transcripción sale de él.",
  "Quand cette option est activée, Koncluí écoute le mot d’activation « OK Koru ». La reconnaissance vocale se fait entièrement sur ce Mac : aucun audio ni transcription n’en sort.",
  "Wenn aktiviert, wartet Koncluí auf das Aktivierungswort „OK Koru“. Die Spracherkennung läuft vollständig auf diesem Mac: Weder Audio noch Transkripte verlassen ihn.",
  "Когда включено, Koncluí слушает слово активации «OK Koru». Распознавание речи работает полностью на этом Mac: ни аудио, ни транскрипции его не покидают.",
  "Etkinleştirildiğinde Koncluí, “OK Koru” uyandırma sözcüğünü dinler. Konuşma tanıma tamamen bu Mac'te çalışır; ses veya döküm Mac'ten dışarı çıkmaz.",
  "Saat diaktifkan, Koncluí mendengarkan kata pemicu “OK Koru”. Pengenalan ucapan berjalan sepenuhnya di Mac ini: tidak ada audio atau transkrip yang keluar darinya.",
  "عند التفعيل، يستمع Koncluí لكلمة التنشيط «OK Koru». يعمل التعرف على الكلام بالكامل على هذا الـ Mac: لا يغادره أي صوت أو نص.",
  "সক্ষম হলে, Koncluí ওয়েক ওয়ার্ড “OK Koru” শোনে। ভাষণ স্বীকৃতি পুরোপুরি এই Mac-এই চলে: কোনো অডিও বা ট্রান্সক্রিপ্ট এটি ছেড়ে যায় না।",
  "सक्षम होने पर, Koncluí वेक वर्ड “OK Koru” सुनता है। वाक् पहचान पूरी तरह इसी Mac पर चलती है: कोई ऑडियो या ट्रांसक्रिप्ट इससे बाहर नहीं जाता।",
  "เมื่อเปิดใช้งาน Koncluí จะฟังคำปลุก “OK Koru” การรู้จำเสียงพูดทำงานบน Mac เครื่องนี้ทั้งหมด ไม่มีเสียงหรือข้อความถอดเสียงออกจากเครื่อง",
  "启用后，Koncluí 会监听唤醒词“OK Koru”。语音识别完全在这台 Mac 上运行：任何音频或文字记录都不会离开它。",
  "啟用後，Koncluí 會聆聽喚醒詞「OK Koru」。語音辨識完全在這台 Mac 上執行，音訊和逐字稿都不會離開它。")

s("hub.notch.voice",
  ("« OK Koru »", "“OK Koru”"), None, None, None, ("« OK Koru »", "„OK Koru“"), None, ("« OK Koru »", "“OK Koru”"),
  None, None, None, None, ("« OK Koru »", "“OK Koru”"), None, None)

s("voice.unknown-transcript",
  ("« %@ »", "“%@”"), ("« %@ »", "“%@”"), None, None, ("« %@ »", "„%@“"), None, ("« %@ »", "“%@”"),
  ("« %@ »", "“%@”"), None, ("« %@ »", "“%@”"), ("« %@ »", "“%@”"), ("« %@ »", "“%@”"), ("« %@ »", "“%@”"), None)


# ---------------------------------------------------------------------------------------------
# Upstream wrote these in English and zh-Hant only (A1-09, A3-12): the Screen picker, the agents' texts, the Codex gauge,
# the Reminders block. 12 texts per row: pt-BR, es, fr, de, ru, tr, id, ar, bn, hi, th, zh-Hans (en and zh-Hant are upstream's).

def fill(key, source, *texts):
    if len(texts) != 12:
        raise ValueError(f"{key!r}: {len(texts)} texts, expected 12")
    r(key, source, None, *texts, None)


fill("Screen", "Screen", "Tela", "Pantalla", "Écran", "Bildschirm", "Экран", "Ekran", "Layar", "الشاشة", "স্ক্রিন", "स्क्रीन",
     "หน้าจอ", "屏幕")
fill("Screen with the notch", "Screen with the notch", "Tela com o notch", "Pantalla con el notch", "Écran avec le notch",
     "Bildschirm mit Notch", "Экран с нотчем", "Notch'lu ekran", "Layar dengan notch", "الشاشة ذات النوتش",
     "নচ-যুক্ত স্ক্রিন", "नॉच वाली स्क्रीन", "หน้าจอที่มี Notch", "带刘海的屏幕")
fill("Follow the mouse", "Follow the mouse", "Seguir o mouse", "Seguir el ratón", "Suivre la souris", "Der Maus folgen",
     "Следовать за мышью", "Fareyi takip et", "Ikuti mouse", "تتبّع الماوس", "মাউস অনুসরণ করুন", "माउस का पीछा करें",
     "ติดตามตำแหน่งเมาส์", "跟随鼠标")
fill("Main screen (menu bar)", "Main screen (menu bar)", "Tela principal (barra de menus)", "Pantalla principal (barra de menús)",
     "Écran principal (barre des menus)", "Hauptbildschirm (Menüleiste)", "Основной экран (строка меню)",
     "Ana ekran (menü çubuğu)", "Layar utama (bilah menu)", "الشاشة الرئيسية (شريط القوائم)", "প্রধান স্ক্রিন (মেনু বার)",
     "मुख्य स्क्रीन (मेनू बार)", "หน้าจอหลัก (แถบเมนู)", "主屏幕（菜单栏）")
fill("Saved screen (not connected)", "Saved screen (not connected)", "Tela salva (desconectada)",
     "Pantalla guardada (no conectada)", "Écran enregistré (non connecté)", "Gespeicherter Bildschirm (nicht verbunden)",
     "Сохранённый экран (не подключён)", "Kayıtlı ekran (bağlı değil)", "Layar tersimpan (tidak terhubung)",
     "الشاشة المحفوظة (غير متصلة)", "সংরক্ষিত স্ক্রিন (সংযুক্ত নেই)", "सहेजी गई स्क्रीन (जुड़ी नहीं)",
     "หน้าจอที่บันทึกไว้ (ไม่ได้เชื่อมต่อ)", "已保存的屏幕（未连接）")
r("On a screen without a notch, Koru sits in a small bar at the top. Follow the mouse moves it to your cursor's screen while it is closed.",
  "On a screen without a notch, Koru sits in a small bar at the top. Follow the mouse moves it to your cursor's screen while it is closed.",
  None,
  "Numa tela sem notch, a Koru fica numa barrinha no topo. “Seguir o mouse” leva a Koru para a tela do cursor enquanto o notch está fechado.",
  "En una pantalla sin notch, Koru se queda en una barra pequeña en la parte superior. «Seguir el ratón» la lleva a la pantalla del cursor mientras el notch está cerrado.",
  "Sur un écran sans notch, Koru reste dans une petite barre en haut. « Suivre la souris » l'amène sur l'écran du curseur tant que le notch est fermé.",
  "Auf einem Bildschirm ohne Notch sitzt Koru in einer kleinen Leiste am oberen Rand. „Der Maus folgen“ bringt sie auf den Bildschirm des Mauszeigers, solange die Notch geschlossen ist.",
  "На экране без выреза Koru живёт в маленькой полосе сверху. «Следовать за мышью» переносит её на экран с курсором, пока нотч закрыт.",
  "Notch'u olmayan bir ekranda Koru, üstteki küçük bir çubukta durur. “Fareyi takip et”, notch kapalıyken Koru'yu imlecin bulunduğu ekrana taşır.",
  "Di layar tanpa notch, Koru berada di bilah kecil di atas. “Ikuti mouse” memindahkannya ke layar tempat kursor berada selama notch tertutup.",
  "على الشاشة التي بلا نوتش، يبقى Koru في شريط صغير أعلاها. «تتبّع الماوس» ينقله إلى شاشة المؤشر ما دام النوتش مغلقًا.",
  "নচ ছাড়া স্ক্রিনে Koru উপরে ছোট একটি বারে থাকে। “মাউস অনুসরণ করুন” নচ বন্ধ থাকলে Koru-কে কার্সরের স্ক্রিনে নিয়ে যায়।",
  "बिना नॉच वाली स्क्रीन पर Koru ऊपर एक छोटी पट्टी में रहता है। “माउस का पीछा करें” नॉच बंद होने पर Koru को कर्सर वाली स्क्रीन पर ले जाता है।",
  "บนหน้าจอที่ไม่มี Notch, Koru จะอยู่ในแถบเล็ก ๆ ด้านบน “ติดตามตำแหน่งเมาส์” จะย้าย Koru ไปยังหน้าจอที่เคอร์เซอร์อยู่ขณะที่ Notch ปิดอยู่",
  "在没有刘海的屏幕上，Koru 会待在顶部的小条里。“跟随鼠标”会在刘海收起时，把 Koru 移到光标所在的屏幕。",
  "在沒有瀏海的螢幕上，Koru 會待在頂端的小型橫條中。「跟隨滑鼠」會在瀏海收合時，將它移至游標所在的螢幕。")

r("Off: sessions in Warp, Terminal, iTerm… show in the notch, but their questions and permission requests are asked in the terminal. On: the notch shows them first, and the terminal waits until you answer there or close the island (up to 2 min).",
  "Off: sessions in Warp, Terminal, iTerm… show in the notch, but their questions and permission requests are asked in the terminal. On: the notch shows them first, and the terminal waits until you answer there or close the island (up to 2 min).",
  None,
  "Desligado: as sessões do Warp, Terminal, iTerm… aparecem no notch, mas as perguntas e permissões são feitas no terminal. Ligado: o notch mostra primeiro, e o terminal espera você responder ou fechar o notch (até 2 min).",
  "Desactivado: las sesiones de Warp, Terminal, iTerm… aparecen en el notch, pero las preguntas y los permisos se piden en el terminal. Activado: el notch los muestra primero y el terminal espera hasta que respondas o cierres el notch (hasta 2 min).",
  "Désactivé : les sessions de Warp, Terminal, iTerm… s'affichent dans le notch, mais les questions et les permissions sont demandées dans le terminal. Activé : le notch les affiche d'abord, et le terminal attend que tu répondes ou que tu fermes le notch (jusqu'à 2 min).",
  "Aus: Sitzungen in Warp, Terminal, iTerm… erscheinen in der Notch, aber ihre Fragen und Berechtigungsanfragen werden im Terminal gestellt. An: Die Notch zeigt sie zuerst, und das Terminal wartet, bis du antwortest oder die Notch schließt (bis zu 2 Min.).",
  "Выкл.: сессии Warp, Terminal, iTerm… видны в нотче, но вопросы и запросы разрешений задаются в терминале. Вкл.: сначала их показывает нотч, а терминал ждёт, пока вы ответите или закроете нотч (до 2 мин).",
  "Kapalı: Warp, Terminal, iTerm… oturumları notch'ta görünür, ancak soruları ve izin istekleri terminalde sorulur. Açık: notch bunları önce gösterir, terminal sen yanıtlayana veya notch'u kapatana kadar bekler (en fazla 2 dk).",
  "Nonaktif: sesi di Warp, Terminal, iTerm… muncul di notch, tetapi pertanyaan dan permintaan izinnya diajukan di terminal. Aktif: notch menampilkannya lebih dulu, dan terminal menunggu sampai kamu menjawab atau menutup notch (maksimal 2 mnt).",
  "متوقف: تظهر جلسات Warp وTerminal وiTerm… في النوتش، لكن أسئلتها وطلبات الأذونات تُطرح في الطرفية. مفعّل: يعرضها النوتش أولًا، وتنتظر الطرفية حتى تجيب أو تغلق النوتش (حتى دقيقتين).",
  "বন্ধ: Warp, Terminal, iTerm… সেশন নচে দেখায়, কিন্তু প্রশ্ন ও অনুমতির অনুরোধ টার্মিনালেই করা হয়। চালু: নচ আগে সেগুলো দেখায়, আর আপনি উত্তর দেওয়া বা নচ বন্ধ করা পর্যন্ত টার্মিনাল অপেক্ষা করে (সর্বোচ্চ ২ মিনিট)।",
  "बंद: Warp, Terminal, iTerm… के सेशन नॉच में दिखते हैं, लेकिन उनके सवाल और अनुमति के अनुरोध टर्मिनल में ही पूछे जाते हैं। चालू: नॉच उन्हें पहले दिखाता है, और टर्मिनल तब तक रुकता है जब तक आप जवाब न दें या नॉच बंद न करें (अधिकतम 2 मिनट)।",
  "ปิด: เซสชันใน Warp, Terminal, iTerm… จะแสดงใน Notch แต่คำถามและคำขออนุญาตจะถามในเทอร์มินัล เปิด: Notch จะแสดงก่อน และเทอร์มินัลจะรอจนกว่าคุณจะตอบหรือปิด Notch (นานสุด 2 นาที)",
  "关闭：Warp、终端、iTerm 等的会话会显示在刘海中，但提问和权限请求仍在终端里进行。开启：刘海会先显示，终端会等你回答或关闭刘海（最多 2 分钟）。",
  "關閉：Warp、終端機、iTerm 等工作階段會顯示在瀏海中，但提問與權限請求仍在終端機中處理。開啟：瀏海會先顯示請求，終端機會等待你回答或關閉瀏海（最多 2 分鐘）。")

# A1-34: no "codex app-server" in a sentence a person reads.
r("Shows your Codex plan usage (weekly limit and free resets left) in the notch header. Koncluí asks the Codex CLI (codex app-server) when the pill shows; nothing is installed. Codex must be signed in with ChatGPT.",
  "Shows your Codex plan usage (weekly limit and free resets left) in the notch header. Koncluí asks the Codex CLI (codex app-server) when the pill shows; nothing is installed. Codex must be signed in with ChatGPT.",
  "Shows your Codex plan usage (weekly limit and free resets left) in the notch header. Koncluí asks Codex when the pill shows; nothing is installed. Codex must be signed in with ChatGPT.",
  "Mostra no topo do notch o uso do seu plano Codex (limite semanal e renovações grátis). O Koncluí pergunta ao Codex quando a aba aparece; nada é instalado. O Codex precisa estar conectado com o ChatGPT.",
  "Muestra en la parte superior del notch el uso de tu plan de Codex (límite semanal y reinicios gratis que quedan). Koncluí le pregunta a Codex cuando aparece la píldora; no se instala nada. Codex debe haber iniciado sesión con ChatGPT.",
  "Affiche en haut du notch l'utilisation de ton forfait Codex (limite hebdomadaire et réinitialisations gratuites restantes). Koncluí interroge Codex quand la pill s'affiche ; rien n'est installé. Codex doit être connecté avec ChatGPT.",
  "Zeigt oben in der Notch deine Codex-Tarifnutzung (Wochenlimit und verbleibende kostenlose Zurücksetzungen). Koncluí fragt Codex ab, wenn die Pill angezeigt wird; es wird nichts installiert. Codex muss mit ChatGPT angemeldet sein.",
  "Показывает вверху нотча расход тарифа Codex (недельный лимит и оставшиеся бесплатные сбросы). Koncluí спрашивает Codex, когда показана пилюля; ничего не устанавливается. Codex должен быть подключён через ChatGPT.",
  "Notch'un üstünde Codex planı kullanımını gösterir (haftalık sınır ve kalan ücretsiz sıfırlamalar). Koncluí, araç görünürken Codex'e sorar; hiçbir şey yüklenmez. Codex'in ChatGPT ile oturum açmış olması gerekir.",
  "Menampilkan pemakaian paket Codex-mu (batas mingguan dan sisa reset gratis) di bagian atas notch. Koncluí bertanya ke Codex saat pil tampil; tidak ada yang dipasang. Codex harus masuk dengan ChatGPT.",
  "يعرض في أعلى النوتش استهلاك خطة Codex (الحد الأسبوعي وعمليات إعادة الضبط المجانية المتبقية). يسأل Koncluí تطبيق Codex عند ظهور الحبة؛ ولا يُثبَّت شيء. يجب أن يكون Codex مسجّلًا الدخول بحساب ChatGPT.",
  "নচের উপরে আপনার Codex প্ল্যানের ব্যবহার দেখায় (সাপ্তাহিক সীমা ও বাকি বিনামূল্যের রিসেট)। পিল দেখা গেলে Koncluí Codex-কে জিজ্ঞেস করে; কিছু ইনস্টল হয় না। Codex-এ ChatGPT দিয়ে সাইন ইন থাকতে হবে।",
  "नॉच के ऊपर आपके Codex प्लान का उपयोग दिखाता है (साप्ताहिक सीमा और बचे मुफ़्त रीसेट)। पिल दिखने पर Koncluí Codex से पूछता है; कुछ इंस्टॉल नहीं होता। Codex में ChatGPT से साइन इन होना चाहिए।",
  "แสดงการใช้แพ็กเกจ Codex ของคุณ (โควตารายสัปดาห์และสิทธิ์รีเซ็ตฟรีที่เหลือ) ที่ด้านบนของ Notch Koncluí จะถาม Codex เมื่อแถบแสดงอยู่ โดยไม่ติดตั้งอะไร Codex ต้องลงชื่อเข้าใช้ด้วย ChatGPT",
  "在刘海顶部显示你的 Codex 套餐用量（每周额度和剩余的免费重置次数）。胶囊显示时，Koncluí 会向 Codex 查询；不会安装任何东西。Codex 必须已用 ChatGPT 登录。",
  "在瀏海標頭中顯示 Codex 方案用量（每週額度及剩餘免費重設次數）。標籤顯示時，Koncluí 會向 Codex 查詢，不會安裝任何東西。Codex 必須已使用 ChatGPT 登入。")

fill("Codex plan", "Codex plan", "Plano Codex", "Plan de Codex", "Forfait Codex", "Codex-Tarif", "Тариф Codex", "Codex planı",
     "Paket Codex", "خطة Codex", "Codex প্ল্যান", "Codex प्लान", "แพ็กเกจ Codex", "Codex 套餐")
# The label column of the gauge is 40 pt wide: short words.
fill("Resets", "Resets", "Reset", "Reset", "Reset", "Reset", "Сброс", "Sıfırla", "Reset", "إعادة", "রিসেট", "रीसेट", "รีเซ็ต",
     "重置")

r("Requires a newer version of Hermes — run: hermes update", "Requires a newer version of Hermes — run: hermes update",
  "Requires a newer version of Hermes. Run: hermes update", "Requer uma versão mais recente do Hermes. Rode: hermes update",
  "Requiere una versión más reciente de Hermes. Ejecuta: hermes update", "Nécessite une version plus récente de Hermes. Lance : hermes update",
  "Erfordert eine neuere Version von Hermes. Führe aus: hermes update", "Нужна более новая версия Hermes. Выполните: hermes update",
  "Daha yeni bir Hermes sürümü gerekir. Şunu çalıştır: hermes update", "Memerlukan Hermes versi lebih baru. Jalankan: hermes update",
  "يتطلب إصدارًا أحدث من Hermes. شغّل: hermes update", "Hermes-এর নতুন সংস্করণ দরকার। চালান: hermes update",
  "Hermes का नया संस्करण चाहिए। चलाएँ: hermes update", "ต้องใช้ Hermes เวอร์ชันใหม่กว่า รันคำสั่ง: hermes update",
  "需要更新版本的 Hermes。请运行：hermes update", None)

# Reminders (the whole block, for pt-BR first).
for _k, *_t in (
    ("Press Escape to close this alert.", "Pressione Esc para fechar este alerta.", "Pulsa Esc para cerrar esta alerta.",
     "Appuie sur Échap pour fermer cette alerte.", "Drücke Esc, um diesen Hinweis zu schließen.",
     "Нажмите Esc, чтобы закрыть это уведомление.", "Bu uyarıyı kapatmak için Esc'ye bas.",
     "Tekan Esc untuk menutup peringatan ini.", "اضغط على Esc لإغلاق هذا التنبيه.", "এই সতর্কতা বন্ধ করতে Esc চাপুন।",
     "इस अलर्ट को बंद करने के लिए Esc दबाएँ।", "กด Esc เพื่อปิดการแจ้งเตือนนี้", "按 Esc 关闭此提醒。"),
    ("Reminders", "Lembretes", "Recordatorios", "Rappels", "Erinnerungen", "Напоминания", "Hatırlatıcılar", "Pengingat",
     "التذكيرات", "রিমাইন্ডার", "रिमाइंडर", "การเตือนความจำ", "提醒事项"),
    ("Create a reminder and choose how Koncluí should interrupt you.",
     "Crie um lembrete e escolha como o Koncluí deve interromper você.",
     "Crea un recordatorio y elige cómo debe interrumpirte Koncluí.",
     "Crée un rappel et choisis comment Koncluí doit t'interrompre.",
     "Erstelle eine Erinnerung und wähle, wie Koncluí dich unterbrechen soll.",
     "Создайте напоминание и выберите, как Koncluí должен вас прерывать.",
     "Bir hatırlatıcı oluştur ve Koncluí'nun seni nasıl böleceğini seç.",
     "Buat pengingat dan pilih cara Koncluí menyela kamu.", "أنشئ تذكيرًا واختر كيف يقاطعك Koncluí.",
     "একটি রিমাইন্ডার তৈরি করুন এবং Koncluí কীভাবে আপনাকে থামাবে তা বেছে নিন।",
     "एक रिमाइंडर बनाएँ और चुनें कि Koncluí आपको कैसे टोके।",
     "สร้างการเตือนความจำและเลือกวิธีที่ Koncluí จะขัดจังหวะคุณ", "创建提醒，并选择 Koncluí 以何种方式打断你。"),
    ("New reminder", "Novo lembrete", "Nuevo recordatorio", "Nouveau rappel", "Neue Erinnerung", "Новое напоминание",
     "Yeni hatırlatıcı", "Pengingat baru", "تذكير جديد", "নতুন রিমাইন্ডার", "नया रिमाइंडर", "การเตือนความจำใหม่", "新建提醒"),
    ("Edit reminder", "Editar lembrete", "Editar recordatorio", "Modifier le rappel", "Erinnerung bearbeiten",
     "Изменить напоминание", "Hatırlatıcıyı düzenle", "Edit pengingat", "تعديل التذكير", "রিমাইন্ডার সম্পাদনা",
     "रिमाइंडर संपादित करें", "แก้ไขการเตือนความจำ", "编辑提醒"),
    ("Title", "Título", "Título", "Titre", "Titel", "Заголовок", "Başlık", "Judul", "العنوان", "শিরোনাম", "शीर्षक",
     "ชื่อเรื่อง", "标题"),
    ("Message (optional)", "Mensagem (opcional)", "Mensaje (opcional)", "Message (facultatif)", "Nachricht (optional)",
     "Сообщение (необязательно)", "Mesaj (isteğe bağlı)", "Pesan (opsional)", "الرسالة (اختياري)", "বার্তা (ঐচ্ছিক)",
     "संदेश (वैकल्पिक)", "ข้อความ (ไม่บังคับ)", "消息（可选）"),
    ("Show at", "Mostrar às", "Mostrar a las", "Afficher à", "Anzeigen um", "Показать в", "Gösterim zamanı",
     "Tampilkan pada", "وقت العرض", "দেখানোর সময়", "दिखाने का समय", "แสดงเมื่อ", "显示时间"),
    ("Repeat", "Repetir", "Repetir", "Répéter", "Wiederholen", "Повторять", "Tekrarla", "Ulangi", "التكرار", "পুনরাবৃত্তি",
     "दोहराएँ", "ทำซ้ำ", "重复"),
    ("Only once", "Só uma vez", "Solo una vez", "Une seule fois", "Nur einmal", "Только один раз", "Yalnızca bir kez",
     "Hanya sekali", "مرة واحدة فقط", "শুধু একবার", "सिर्फ़ एक बार", "ครั้งเดียว", "仅一次"),
    ("Every day", "Todos os dias", "Todos los días", "Tous les jours", "Jeden Tag", "Каждый день", "Her gün", "Setiap hari",
     "كل يوم", "প্রতিদিন", "हर दिन", "ทุกวัน", "每天"),
    ("Weekdays", "Dias úteis", "Días laborables", "Jours ouvrés", "Wochentage", "По будням", "Hafta içi", "Hari kerja",
     "أيام الأسبوع", "কর্মদিবস", "कार्यदिवस", "วันธรรมดา", "工作日"),
    ("Every week", "Toda semana", "Cada semana", "Chaque semaine", "Jede Woche", "Каждую неделю", "Her hafta",
     "Setiap minggu", "كل أسبوع", "প্রতি সপ্তাহে", "हर हफ़्ते", "ทุกสัปดาห์", "每周"),
    ("Floating card", "Cartão flutuante", "Tarjeta flotante", "Carte flottante", "Schwebende Karte", "Плавающая карточка",
     "Yüzen kart", "Kartu mengambang", "بطاقة عائمة", "ভাসমান কার্ড", "फ़्लोटिंग कार्ड", "การ์ดลอย", "悬浮卡片"),
    ("Full-screen alert", "Alerta em tela cheia", "Alerta a pantalla completa", "Alerte plein écran", "Vollbild-Hinweis",
     "Полноэкранное уведомление", "Tam ekran uyarı", "Peringatan layar penuh", "تنبيه بملء الشاشة", "ফুল-স্ক্রিন সতর্কতা",
     "फ़ुल-स्क्रीन अलर्ट", "การแจ้งเตือนเต็มหน้าจอ", "全屏提醒"),
    ("Width", "Largura", "Ancho", "Largeur", "Breite", "Ширина", "Genişlik", "Lebar", "العرض", "প্রস্থ", "चौड़ाई",
     "ความกว้าง", "宽度"),
    ("Height", "Altura", "Alto", "Hauteur", "Höhe", "Высота", "Yükseklik", "Tinggi", "الارتفاع", "উচ্চতা", "ऊँचाई",
     "ความสูง", "高度"),
    ("Horizontal position", "Posição horizontal", "Posición horizontal", "Position horizontale", "Horizontale Position",
     "Положение по горизонтали", "Yatay konum", "Posisi horizontal", "الموضع الأفقي", "অনুভূমিক অবস্থান",
     "क्षैतिज स्थिति", "ตำแหน่งแนวนอน", "水平位置"),
    ("Alert content width", "Largura do conteúdo do alerta", "Ancho del contenido de la alerta",
     "Largeur du contenu de l'alerte", "Breite des Hinweisinhalts", "Ширина содержимого уведомления",
     "Uyarı içeriği genişliği", "Lebar konten peringatan", "عرض محتوى التنبيه", "সতর্কতার বিষয়বস্তুর প্রস্থ",
     "अलर्ट सामग्री की चौड़ाई", "ความกว้างของเนื้อหาการแจ้งเตือน", "提醒内容宽度"),
    ("Offer snooze", "Oferecer soneca", "Ofrecer posponer", "Proposer de répéter plus tard", "Schlummern anbieten",
     "Предлагать отложить", "Ertelemeyi sun", "Tawarkan tunda", "عرض خيار التأجيل", "স্নুজের বিকল্প দিন",
     "स्नूज़ का विकल्प दें", "เสนอตัวเลือกเลื่อนการเตือน", "提供稍后提醒"),
    ("Remove custom Snooze buttons before disabling snooze.",
     "Remova os botões de soneca personalizados antes de desligar a soneca.",
     "Quita los botones de posponer personalizados antes de desactivar la opción de posponer.",
     "Retire les boutons de report personnalisés avant de désactiver le report.",
     "Entferne eigene Schlummern-Tasten, bevor du Schlummern ausschaltest.",
     "Удалите свои кнопки «Отложить», прежде чем выключать откладывание.",
     "Ertelemeyi kapatmadan önce özel Ertele düğmelerini kaldır.",
     "Hapus tombol Tunda khusus sebelum menonaktifkan tunda.", "أزل أزرار التأجيل المخصصة قبل إيقاف التأجيل.",
     "স্নুজ বন্ধ করার আগে কাস্টম স্নুজ বোতামগুলো সরিয়ে ফেলুন।", "स्नूज़ बंद करने से पहले कस्टम स्नूज़ बटन हटाएँ।",
     "ลบปุ่มเลื่อนการเตือนที่กำหนดเองออกก่อนปิดการเลื่อนการเตือน", "关闭稍后提醒前，请先移除自定义的稍后提醒按钮。"),
    ("SF Symbol (optional)", "SF Symbol (opcional)", "SF Symbol (opcional)", "SF Symbol (facultatif)", "SF Symbol (optional)",
     "SF Symbol (необязательно)", "SF Symbol (isteğe bağlı)", "SF Symbol (opsional)", "SF Symbol (اختياري)",
     "SF Symbol (ঐচ্ছিক)", "SF Symbol (वैकल्पिक)", "SF Symbol (ไม่บังคับ)", "SF Symbol（可选）"),
    ("Choose image…", "Escolher imagem…", "Elegir imagen…", "Choisir une image…", "Bild auswählen…",
     "Выбрать изображение…", "Görsel seç…", "Pilih gambar…", "اختيار صورة…", "ছবি বেছে নিন…", "छवि चुनें…",
     "เลือกรูปภาพ…", "选择图片…"),
    ("Change image…", "Trocar imagem…", "Cambiar imagen…", "Changer d'image…", "Bild ändern…", "Заменить изображение…",
     "Görseli değiştir…", "Ganti gambar…", "تغيير الصورة…", "ছবি বদলান…", "छवि बदलें…", "เปลี่ยนรูปภาพ…", "更换图片…"),
    ("Remove image", "Remover imagem", "Quitar imagen", "Retirer l'image", "Bild entfernen", "Удалить изображение",
     "Görseli kaldır", "Hapus gambar", "إزالة الصورة", "ছবি সরান", "छवि हटाएँ", "ลบรูปภาพ", "移除图片"),
    ("Buttons", "Botões", "Botones", "Boutons", "Tasten", "Кнопки", "Düğmeler", "Tombol", "الأزرار", "বোতাম", "बटन",
     "ปุ่ม", "按钮"),
    ("Add button", "Adicionar botão", "Añadir botón", "Ajouter un bouton", "Taste hinzufügen", "Добавить кнопку",
     "Düğme ekle", "Tambah tombol", "إضافة زر", "বোতাম যোগ করুন", "बटन जोड़ें", "เพิ่มปุ่ม", "添加按钮"),
    ("Create reminder", "Criar lembrete", "Crear recordatorio", "Créer le rappel", "Erinnerung erstellen",
     "Создать напоминание", "Hatırlatıcı oluştur", "Buat pengingat", "إنشاء تذكير", "রিমাইন্ডার তৈরি করুন",
     "रिमाइंडर बनाएँ", "สร้างการเตือนความจำ", "创建提醒"),
    ("Save changes", "Salvar alterações", "Guardar cambios", "Enregistrer les modifications", "Änderungen sichern",
     "Сохранить изменения", "Değişiklikleri kaydet", "Simpan perubahan", "حفظ التغييرات", "পরিবর্তন সংরক্ষণ করুন",
     "बदलाव सहेजें", "บันทึกการเปลี่ยนแปลง", "保存更改"),
    ("Reminders on this Mac", "Lembretes neste Mac", "Recordatorios en este Mac", "Rappels sur ce Mac",
     "Erinnerungen auf diesem Mac", "Напоминания на этом Mac", "Bu Mac'teki hatırlatıcılar", "Pengingat di Mac ini",
     "التذكيرات على هذا الـ Mac", "এই Mac-এর রিমাইন্ডার", "इस Mac पर रिमाइंडर", "การเตือนความจำบน Mac เครื่องนี้",
     "此 Mac 上的提醒"),
    ("No reminders yet. Create one above or connect a local MCP client below.",
     "Nenhum lembrete ainda. Crie um acima ou conecte um cliente MCP local abaixo.",
     "Aún no hay recordatorios. Crea uno arriba o conecta un cliente MCP local abajo.",
     "Aucun rappel pour l'instant. Crée-en un ci-dessus ou connecte un client MCP local ci-dessous.",
     "Noch keine Erinnerungen. Erstelle oben eine oder verbinde unten einen lokalen MCP-Client.",
     "Напоминаний пока нет. Создайте его выше или подключите локальный клиент MCP ниже.",
     "Henüz hatırlatıcı yok. Yukarıdan bir tane oluştur ya da aşağıdan yerel bir MCP istemcisi bağla.",
     "Belum ada pengingat. Buat di atas atau hubungkan klien MCP lokal di bawah.",
     "لا توجد تذكيرات بعد. أنشئ واحدًا أعلاه أو اربط عميل MCP محليًا أدناه.",
     "এখনও কোনো রিমাইন্ডার নেই। উপরে একটি তৈরি করুন বা নিচে একটি লোকাল MCP ক্লায়েন্ট যুক্ত করুন।",
     "अभी कोई रिमाइंडर नहीं है। ऊपर एक बनाएँ या नीचे एक लोकल MCP क्लाइंट जोड़ें।",
     "ยังไม่มีการเตือนความจำ สร้างด้านบน หรือเชื่อมต่อไคลเอนต์ MCP ในเครื่องด้านล่าง",
     "还没有提醒。请在上方创建，或在下方连接本地 MCP 客户端。"),
    ("Saved reminders could not be loaded. Changes are disabled to protect the existing file.",
     "Não foi possível carregar os lembretes salvos. As alterações ficam desativadas para proteger o arquivo existente.",
     "No se pudieron cargar los recordatorios guardados. Los cambios están desactivados para proteger el archivo existente.",
     "Impossible de charger les rappels enregistrés. Les modifications sont désactivées pour protéger le fichier existant.",
     "Die gesicherten Erinnerungen konnten nicht geladen werden. Änderungen sind deaktiviert, um die vorhandene Datei zu schützen.",
     "Не удалось загрузить сохранённые напоминания. Изменения отключены, чтобы защитить существующий файл.",
     "Kayıtlı hatırlatıcılar yüklenemedi. Mevcut dosyayı korumak için değişiklikler kapatıldı.",
     "Pengingat tersimpan tidak dapat dimuat. Perubahan dinonaktifkan untuk melindungi berkas yang ada.",
     "تعذّر تحميل التذكيرات المحفوظة. عُطّلت التغييرات لحماية الملف الحالي.",
     "সংরক্ষিত রিমাইন্ডার লোড করা যায়নি। বিদ্যমান ফাইল রক্ষা করতে পরিবর্তন বন্ধ রাখা হয়েছে।",
     "सहेजे गए रिमाइंडर लोड नहीं हो सके। मौजूदा फ़ाइल की सुरक्षा के लिए बदलाव बंद हैं।",
     "โหลดการเตือนความจำที่บันทึกไว้ไม่ได้ ระบบปิดการแก้ไขเพื่อปกป้องไฟล์เดิม",
     "无法载入已保存的提醒。为保护现有文件，已停用更改功能。"),
    ("Show now", "Mostrar agora", "Mostrar ahora", "Afficher maintenant", "Jetzt anzeigen", "Показать сейчас",
     "Şimdi göster", "Tampilkan sekarang", "عرض الآن", "এখনই দেখান", "अभी दिखाएँ", "แสดงตอนนี้", "立即显示"),
    ("Show this reminder now", "Mostrar este lembrete agora", "Mostrar este recordatorio ahora",
     "Afficher ce rappel maintenant", "Diese Erinnerung jetzt anzeigen", "Показать это напоминание сейчас",
     "Bu hatırlatıcıyı şimdi göster", "Tampilkan pengingat ini sekarang", "عرض هذا التذكير الآن",
     "এই রিমাইন্ডার এখনই দেখান", "यह रिमाइंडर अभी दिखाएँ", "แสดงการเตือนความจำนี้ตอนนี้", "立即显示此提醒"),
    ("Edit", "Editar", "Editar", "Modifier", "Bearbeiten", "Изменить", "Düzenle", "Edit", "تعديل", "সম্পাদনা",
     "संपादित करें", "แก้ไข", "编辑"),
    ("Edit this reminder", "Editar este lembrete", "Editar este recordatorio", "Modifier ce rappel",
     "Diese Erinnerung bearbeiten", "Изменить это напоминание", "Bu hatırlatıcıyı düzenle", "Edit pengingat ini",
     "تعديل هذا التذكير", "এই রিমাইন্ডার সম্পাদনা করুন", "यह रिमाइंडर संपादित करें", "แก้ไขการเตือนความจำนี้", "编辑此提醒"),
    ("Stop", "Parar", "Detener", "Arrêter", "Stoppen", "Остановить", "Durdur", "Hentikan", "إيقاف", "বন্ধ করুন", "रोकें",
     "หยุด", "停止"),
    ("Stop future occurrences", "Parar as próximas ocorrências", "Detener las próximas repeticiones",
     "Arrêter les prochaines occurrences", "Künftige Wiederholungen stoppen", "Остановить будущие повторы",
     "Sonraki tekrarları durdur", "Hentikan kemunculan berikutnya", "إيقاف المرات القادمة",
     "পরবর্তী পুনরাবৃত্তি বন্ধ করুন", "आगे की पुनरावृत्तियाँ रोकें", "หยุดการเตือนครั้งต่อไป", "停止后续提醒"),
    ("Delete", "Apagar", "Eliminar", "Supprimer", "Löschen", "Удалить", "Sil", "Hapus", "حذف", "মুছুন", "हटाएँ", "ลบ", "删除"),
    ("Delete this reminder", "Apagar este lembrete", "Eliminar este recordatorio", "Supprimer ce rappel",
     "Diese Erinnerung löschen", "Удалить это напоминание", "Bu hatırlatıcıyı sil", "Hapus pengingat ini",
     "حذف هذا التذكير", "এই রিমাইন্ডার মুছুন", "यह रिमाइंडर हटाएँ", "ลบการเตือนความจำนี้", "删除此提醒"),
    ("Delete reminder?", "Apagar o lembrete?", "¿Eliminar el recordatorio?", "Supprimer le rappel ?",
     "Erinnerung löschen?", "Удалить напоминание?", "Hatırlatıcı silinsin mi?", "Hapus pengingat?", "حذف التذكير؟",
     "রিমাইন্ডার মুছবেন?", "रिमाइंडर हटाएँ?", "ลบการเตือนความจำหรือไม่", "要删除此提醒吗？"),
    ("Connect a local MCP client", "Conectar um cliente MCP local", "Conectar un cliente MCP local",
     "Connecter un client MCP local", "Lokalen MCP-Client verbinden", "Подключить локальный клиент MCP",
     "Yerel bir MCP istemcisi bağla", "Hubungkan klien MCP lokal", "ربط عميل MCP محلي",
     "একটি লোকাল MCP ক্লায়েন্ট যুক্ত করুন", "लोकल MCP क्लाइंट जोड़ें", "เชื่อมต่อไคลเอนต์ MCP ในเครื่อง",
     "连接本地 MCP 客户端"),
    ("Koncluí keeps reminders on this Mac. The MCP bridge uses a private local socket; it does not edit other apps’ settings or send calendar data.",
     "O Koncluí guarda os lembretes neste Mac. A ponte MCP usa um socket local privado; ela não altera os ajustes de outros apps nem envia dados de calendário.",
     "Koncluí guarda los recordatorios en este Mac. El puente MCP usa un socket local privado; no modifica los ajustes de otras apps ni envía datos del calendario.",
     "Koncluí garde les rappels sur ce Mac. Le pont MCP utilise un socket local privé ; il ne modifie pas les réglages d'autres apps et n'envoie aucune donnée de calendrier.",
     "Koncluí speichert Erinnerungen auf diesem Mac. Die MCP-Brücke nutzt einen privaten lokalen Socket; sie ändert keine Einstellungen anderer Apps und sendet keine Kalenderdaten.",
     "Koncluí хранит напоминания на этом Mac. Мост MCP использует закрытый локальный сокет: он не меняет настройки других приложений и не отправляет данные календаря.",
     "Koncluí hatırlatıcıları bu Mac'te tutar. MCP köprüsü özel bir yerel soket kullanır; diğer uygulamaların ayarlarını değiştirmez ve takvim verisi göndermez.",
     "Koncluí menyimpan pengingat di Mac ini. Jembatan MCP memakai soket lokal pribadi; ia tidak mengubah pengaturan app lain dan tidak mengirim data kalender.",
     "يحتفظ Koncluí بالتذكيرات على هذا الـ Mac. يستخدم جسر MCP مقبسًا محليًا خاصًا؛ ولا يعدّل إعدادات التطبيقات الأخرى ولا يرسل بيانات التقويم.",
     "Koncluí রিমাইন্ডার এই Mac-এই রাখে। MCP ব্রিজ একটি ব্যক্তিগত লোকাল সকেট ব্যবহার করে; এটি অন্য অ্যাপের সেটিংস বদলায় না বা ক্যালেন্ডারের তথ্য পাঠায় না।",
     "Koncluí रिमाइंडर इसी Mac पर रखता है। MCP ब्रिज एक निजी लोकल सॉकेट इस्तेमाल करता है; यह दूसरे ऐप की सेटिंग्स नहीं बदलता और कैलेंडर डेटा नहीं भेजता।",
     "Koncluí เก็บการเตือนความจำไว้บน Mac เครื่องนี้ สะพาน MCP ใช้ซ็อกเก็ตในเครื่องแบบส่วนตัว ไม่แก้ไขการตั้งค่าของแอปอื่น และไม่ส่งข้อมูลปฏิทิน",
     "Koncluí 会把提醒保存在这台 Mac 上。MCP 桥接使用私有的本地套接字，不会修改其他 App 的设置，也不会发送日历数据。"),
    ("Add this server to your MCP client configuration, then restart that client:",
     "Adicione este servidor à configuração do seu cliente MCP e reinicie o cliente:",
     "Añade este servidor a la configuración de tu cliente MCP y reinicia ese cliente:",
     "Ajoute ce serveur à la configuration de ton client MCP, puis redémarre ce client :",
     "Füge diesen Server zur Konfiguration deines MCP-Clients hinzu und starte den Client neu:",
     "Добавьте этот сервер в настройки вашего клиента MCP и перезапустите клиент:",
     "Bu sunucuyu MCP istemcisinin yapılandırmasına ekle ve istemciyi yeniden başlat:",
     "Tambahkan server ini ke konfigurasi klien MCP-mu, lalu mulai ulang klien itu:",
     "أضف هذا الخادم إلى إعدادات عميل MCP لديك، ثم أعد تشغيل العميل:",
     "এই সার্ভারটি আপনার MCP ক্লায়েন্টের কনফিগারেশনে যোগ করুন, তারপর ক্লায়েন্টটি আবার চালু করুন:",
     "इस सर्वर को अपने MCP क्लाइंट के कॉन्फ़िगरेशन में जोड़ें, फिर उस क्लाइंट को दोबारा शुरू करें:",
     "เพิ่มเซิร์ฟเวอร์นี้ในการตั้งค่าไคลเอนต์ MCP ของคุณ แล้วเริ่มไคลเอนต์นั้นใหม่:",
     "把此服务器添加到你的 MCP 客户端配置中，然后重启该客户端："),
    ("Copy MCP configuration", "Copiar a configuração MCP", "Copiar la configuración MCP", "Copier la configuration MCP",
     "MCP-Konfiguration kopieren", "Скопировать конфигурацию MCP", "MCP yapılandırmasını kopyala", "Salin konfigurasi MCP",
     "نسخ إعدادات MCP", "MCP কনফিগারেশন কপি করুন", "MCP कॉन्फ़िगरेशन कॉपी करें", "คัดลอกการตั้งค่า MCP", "复制 MCP 配置"),
    ("Copied", "Copiado", "Copiado", "Copié", "Kopiert", "Скопировано", "Kopyalandı", "Tersalin", "تم النسخ",
     "কপি হয়েছে", "कॉपी हो गया", "คัดลอกแล้ว", "已复制"),
    ("Button title", "Título do botão", "Título del botón", "Titre du bouton", "Tastentitel", "Название кнопки",
     "Düğme başlığı", "Judul tombol", "عنوان الزر", "বোতামের শিরোনাম", "बटन का शीर्षक", "ชื่อปุ่ม", "按钮标题"),
    ("Button action", "Ação do botão", "Acción del botón", "Action du bouton", "Tastenaktion", "Действие кнопки",
     "Düğme eylemi", "Aksi tombol", "إجراء الزر", "বোতামের কাজ", "बटन की क्रिया", "การทำงานของปุ่ม", "按钮操作"),
    ("Open link", "Abrir link", "Abrir enlace", "Ouvrir le lien", "Link öffnen", "Открыть ссылку", "Bağlantıyı aç",
     "Buka tautan", "فتح الرابط", "লিংক খুলুন", "लिंक खोलें", "เปิดลิงก์", "打开链接"),
    ("Snooze", "Soneca", "Posponer", "Reporter", "Schlummern", "Отложить", "Ertele", "Tunda", "تأجيل", "স্নুজ", "स्नूज़",
     "เลื่อนการเตือน", "稍后提醒"),
    ("Complete", "Concluir", "Completar", "Terminer", "Erledigt", "Выполнено", "Tamamla", "Selesai", "إكمال", "সম্পন্ন",
     "पूरा करें", "เสร็จสิ้น", "完成"),
    ("Dismiss", "Dispensar", "Descartar", "Ignorer", "Schließen", "Закрыть", "Kapat", "Tutup", "تجاهل", "বন্ধ করুন",
     "खारिज करें", "ปิด", "关闭"),
    ("Stop reminder", "Parar lembrete", "Detener recordatorio", "Arrêter le rappel", "Erinnerung stoppen",
     "Остановить напоминание", "Hatırlatıcıyı durdur", "Hentikan pengingat", "إيقاف التذكير", "রিমাইন্ডার বন্ধ করুন",
     "रिमाइंडर रोकें", "หยุดการเตือนความจำ", "停止提醒"),
    ("Vertical position from top", "Posição vertical a partir do topo", "Posición vertical desde arriba",
     "Position verticale depuis le haut", "Vertikale Position von oben", "Положение по вертикали от верха",
     "Üstten dikey konum", "Posisi vertikal dari atas", "الموضع الرأسي من الأعلى", "উপর থেকে উল্লম্ব অবস্থান",
     "ऊपर से ऊर्ध्वाधर स्थिति", "ตำแหน่งแนวตั้งจากด้านบน", "距顶部的垂直位置"),
    ("That image could not be decoded. Choose a valid PNG or JPEG.",
     "Não foi possível abrir essa imagem. Escolha um PNG ou JPEG válido.",
     "No se pudo leer esa imagen. Elige un PNG o JPEG válido.",
     "Cette image n'a pas pu être lue. Choisis un PNG ou un JPEG valide.",
     "Dieses Bild konnte nicht gelesen werden. Wähle ein gültiges PNG oder JPEG.",
     "Не удалось прочитать это изображение. Выберите корректный PNG или JPEG.",
     "Bu görsel okunamadı. Geçerli bir PNG veya JPEG seç.",
     "Gambar itu tidak dapat dibaca. Pilih PNG atau JPEG yang valid.",
     "تعذّرت قراءة هذه الصورة. اختر ملف PNG أو JPEG صالحًا.",
     "ছবিটি পড়া যায়নি। একটি বৈধ PNG বা JPEG বেছে নিন।", "वह छवि पढ़ी नहीं जा सकी। मान्य PNG या JPEG चुनें।",
     "อ่านรูปภาพนี้ไม่ได้ เลือกไฟล์ PNG หรือ JPEG ที่ใช้ได้", "无法读取该图片。请选择有效的 PNG 或 JPEG。"),
    ("Remove button", "Remover botão", "Quitar botón", "Retirer le bouton", "Taste entfernen", "Удалить кнопку",
     "Düğmeyi kaldır", "Hapus tombol", "إزالة الزر", "বোতাম সরান", "बटन हटाएँ", "ลบปุ่ม", "移除按钮"),
    ("HTTPS link", "Link HTTPS", "Enlace HTTPS", "Lien HTTPS", "HTTPS-Link", "Ссылка HTTPS", "HTTPS bağlantısı",
     "Tautan HTTPS", "رابط HTTPS", "HTTPS লিংক", "HTTPS लिंक", "ลิงก์ HTTPS", "HTTPS 链接"),
):
    fill(_k, _k, *_t)


# ---------------------------------------------------------------------------------------------
# Microcopy that contradicted itself or read like code (A1-23, A1-25, A1-27, A1-34, A1-50, A3-23, A3-35).

# One line in the stats card ("contra digitar a 45 pal..." was cut mid-word): short enough for one line in every language.
r("hub.stat.saved-note", "vs typing at 45 words/min",
  "vs typing at 45/min", "vs. digitar a 45/min", "frente a teclear 45/min", "vs clavier à 45/min", "vs. Tippen mit 45/Min.",
  "против набора 45/мин", "yazma 45/dk'ya karşı", "vs. mengetik 45/mnt", "مقابل الكتابة بـ45/د", "টাইপিং ৪৫/মিনিটের তুলনায়",
  "टाइपिंग 45/मिनट के मुकाबले", "เทียบกับพิมพ์ 45/นาที", "对比每分钟打字 45 个", None)

r("hub.notch.chat", "The AI of the notch's chat, with your own keys.",
  "The notch chat's AI: your Claude or ChatGPT subscription, or an API key.",
  "A IA do chat do notch: sua assinatura do Claude ou do ChatGPT, ou uma chave de API.",
  "La IA del chat del notch: tu suscripción de Claude o ChatGPT, o una clave de API.",
  "L'IA du chat du notch : ton abonnement Claude ou ChatGPT, ou une clé API.",
  "Die KI im Chat der Notch: dein Claude- oder ChatGPT-Abo oder ein API-Schlüssel.",
  "ИИ для чата в нотче: ваша подписка Claude или ChatGPT либо ключ API.",
  "Notch sohbetinin yapay zekâsı: Claude veya ChatGPT aboneliğin ya da bir API anahtarı.",
  "AI untuk obrolan notch: langganan Claude atau ChatGPT-mu, atau kunci API.",
  "ذكاء دردشة النوتش: اشتراكك في Claude أو ChatGPT، أو مفتاح API.",
  "নচ চ্যাটের AI: আপনার Claude বা ChatGPT সাবস্ক্রিপশন, অথবা একটি API কী।",
  "नॉच चैट का AI: आपकी Claude या ChatGPT सदस्यता, या एक API कुंजी।",
  "AI สำหรับแชตใน Notch: การสมัครสมาชิก Claude หรือ ChatGPT ของคุณ หรือคีย์ API",
  "刘海聊天使用的 AI：你的 Claude 或 ChatGPT 订阅，或一个 API 密钥。",
  "瀏海聊天使用的 AI：你的 Claude 或 ChatGPT 訂閱，或一組 API 金鑰。")

# The top line of Active pills and the "Add…" line below it disagreed ("only what you declare" / "what it recognized").
r("Choose the tools you use. Koncluí only shows what you declare here.",
  "Choose the tools you use. Koncluí only shows what you declare here.",
  "Turn on the tools you use: only pills that are on show in the notch.",
  "Ligue as ferramentas que você usa: só as abas ligadas aparecem no notch.",
  "Activa las herramientas que usas: solo las píldoras activas aparecen en el notch.",
  "Active les outils que tu utilises : seules les pills activées apparaissent dans le notch.",
  "Schalte die Werkzeuge ein, die du nutzt: Nur aktive Pills erscheinen in der Notch.",
  "Включите нужные инструменты: в нотче появляются только включённые пилюли.",
  "Kullandığın araçları aç: notch'ta yalnızca açık olan araçlar görünür.",
  "Aktifkan alat yang kamu pakai: hanya pil yang aktif tampil di notch.",
  "فعّل الأدوات التي تستخدمها: لا تظهر في النوتش إلا الحبات المفعّلة.",
  "আপনি যে টুলগুলো ব্যবহার করেন সেগুলো চালু করুন: শুধু চালু পিলগুলো নচে দেখায়।",
  "जो टूल आप इस्तेमाल करते हैं उन्हें चालू करें: नॉच में सिर्फ़ चालू पिल दिखती हैं।",
  "เปิดเครื่องมือที่คุณใช้: เฉพาะแถบที่เปิดอยู่เท่านั้นที่จะแสดงใน Notch",
  "打开你使用的工具：只有已开启的胶囊会显示在刘海中。",
  "開啟你使用的工具：只有已開啟的標籤會顯示在瀏海中。")

r("hub.hint %@", "Hold %@ anywhere, speak, let go: it's pasted.",
  "Hold %@ in any app, speak, let go: the text appears where you type.",
  "Segure %@ em qualquer app, fale e solte: o texto aparece onde você digita.",
  "Mantén %@ en cualquier app, habla y suelta: el texto aparece donde escribes.",
  "Maintiens %@ dans n'importe quelle app, parle, relâche : le texte apparaît là où tu écris.",
  "Halte %@ in einer beliebigen App gedrückt, sprich und lass los: Der Text erscheint dort, wo du tippst.",
  "Удерживайте %@ в любом приложении, говорите, отпустите: текст появится там, где вы печатаете.",
  "Herhangi bir uygulamada %@ tuşunu basılı tut, konuş, bırak: metin yazdığın yerde belirir.",
  "Tahan %@ di app mana pun, bicara, lepas: teks muncul di tempat kamu mengetik.",
  "اضغط مطولًا على %@ في أي تطبيق، تحدّث، ثم اترك: يظهر النص حيث تكتب.",
  "যেকোনো অ্যাপে %@ চেপে ধরুন, বলুন, ছেড়ে দিন: যেখানে টাইপ করছেন সেখানেই লেখা আসবে।",
  "किसी भी ऐप में %@ दबाए रखें, बोलें, छोड़ें: टेक्स्ट वहीं आ जाता है जहाँ आप टाइप करते हैं।",
  "กด %@ ค้างไว้ในแอปใดก็ได้ พูด แล้วปล่อย ข้อความจะปรากฏตรงที่คุณพิมพ์",
  "在任何 App 中按住 %@，说话，松开：文字会出现在你输入的位置。",
  "在任何 App 中按住 %@ 說話，放開後文字會出現在你輸入的位置。")

r("flow.translate-on %@", "Whatever you speak, it's pasted in %@.",
  "Speak in any language: the text is pasted in %@.", "Fale em qualquer idioma: o texto é colado em %@.", None,
  "Parle dans n'importe quelle langue : le texte est collé en %@.", None,
  "Говорите на любом языке: текст будет вставлен на языке «%@».", None, None, None, None, None, None, None, None)

r("hub.style-default", "Other apps",
  None, "Todos os outros apps", None, None, None, None, None, None, None, None, None, None, None, None)

# A1-34: no path, no "relay" in a sentence a person reads.
r("plan.description",
  "Shows your Claude plan usage (5-hour and weekly limits) in the notch header. Koncluí adds a status line relay in ~/.claude/settings.json. If you already have a status line, it keeps working as before. Pro and Max plans only.",
  "Shows your Claude plan usage (5-hour and weekly limits) in the notch header. Koncluí adds a status line to Claude Code to read the usage; yours keeps working. Pro and Max plans only.",
  "Mostra o uso do seu plano Claude (limites de 5 horas e semanais) no cabeçalho do notch. O Koncluí acrescenta uma linha de status ao Claude Code para ler o uso; a sua continua funcionando. Apenas planos Pro e Max.",
  "Muestra el uso de tu plan de Claude (límites de 5 horas y semanales) en el encabezado del notch. Koncluí añade una línea de estado a Claude Code para leer el uso; la tuya sigue funcionando. Solo planes Pro y Max.",
  "Affiche l'utilisation de ton forfait Claude (limites de 5 heures et hebdomadaire) dans l'en-tête du notch. Koncluí ajoute une ligne de statut à Claude Code pour lire l'utilisation ; la tienne continue de fonctionner. Forfaits Pro et Max uniquement.",
  "Zeigt deine Claude-Tarifnutzung (5-Stunden- und Wochenlimits) im Kopfbereich der Notch. Koncluí ergänzt in Claude Code eine Statuszeile, um die Nutzung zu lesen; deine eigene funktioniert weiter. Nur für Pro- und Max-Tarife.",
  "Показывает использование плана Claude (лимиты на 5 часов и на неделю) в шапке нотча. Koncluí добавляет в Claude Code строку статуса, чтобы читать расход; ваша продолжит работать. Только для планов Pro и Max.",
  "Claude plan kullanımını (5 saatlik ve haftalık sınırlar) notch başlığında gösterir. Koncluí, kullanımı okumak için Claude Code'a bir durum satırı ekler; seninki çalışmaya devam eder. Yalnızca Pro ve Max planları için.",
  "Menampilkan penggunaan paket Claude (batas 5 jam dan mingguan) di header notch. Koncluí menambahkan baris status ke Claude Code untuk membaca penggunaan; baris statusmu tetap berjalan. Hanya untuk paket Pro dan Max.",
  "يعرض استخدام خطة Claude (حدود 5 ساعات والحدود الأسبوعية) في ترويسة النوتش. يضيف Koncluí سطر حالة إلى Claude Code لقراءة الاستخدام، ويستمر سطر الحالة الخاص بك في العمل. للخطتين Pro وMax فقط.",
  "নচ হেডারে আপনার Claude প্ল্যানের ব্যবহার (৫ ঘণ্টা ও সাপ্তাহিক সীমা) দেখায়। ব্যবহার পড়তে Koncluí Claude Code-এ একটি স্ট্যাটাস লাইন যোগ করে; আপনারটি আগের মতোই কাজ করে। শুধুমাত্র Pro এবং Max প্ল্যানের জন্য।",
  "नॉच हेडर में आपके Claude प्लान का उपयोग (5 घंटे और साप्ताहिक सीमाएं) दिखाता है। उपयोग पढ़ने के लिए Koncluí Claude Code में एक स्टेटस लाइन जोड़ता है; आपकी अपनी लाइन पहले की तरह काम करती रहती है। केवल Pro और Max प्लान के लिए।",
  "แสดงปริมาณการใช้แพ็กเกจ Claude (ขีดจำกัด 5 ชั่วโมงและรายสัปดาห์) ที่ส่วนหัวของ Notch Koncluí เพิ่มบรรทัดสถานะให้ Claude Code เพื่ออ่านปริมาณการใช้ ส่วนบรรทัดสถานะของคุณยังทำงานเหมือนเดิม ใช้ได้กับแพ็กเกจ Pro และ Max เท่านั้น",
  "在刘海标头中显示你的 Claude 计划用量（5 小时及每周限额）。Koncluí 会给 Claude Code 添加一条状态栏来读取用量；你原有的状态栏照常运行。仅限 Pro 和 Max 计划。",
  "在瀏海標頭顯示 Claude 方案用量（5 小時與每週額度）。Koncluí 會為 Claude Code 新增一條狀態列來讀取用量；你原有的狀態列仍會照常運作。僅適用於 Pro 與 Max 方案。")

r("plan.relay.installed", "Relay: installed",
  "Installed", "Instalado", "Instalado", "Installé", "Installiert", "Установлено", "Kurulu", "Terpasang", "مثبَّت",
  "ইনস্টল আছে", "इंस्टॉल है", "ติดตั้งแล้ว", "已安装", "已安裝")
r("plan.relay.not-installed", "Relay: not installed",
  "Not installed", "Não instalado", "No instalado", "Non installé", "Nicht installiert", "Не установлено", "Kurulu değil",
  "Belum terpasang", "غير مثبَّت", "ইনস্টল নেই", "इंस्टॉल नहीं है", "ยังไม่ได้ติดตั้ง", "未安装", "尚未安裝")
r("plan.relay.install", "Install relay",
  "Install", "Instalar", "Instalar", "Installer", "Installieren", "Установить", "Kur", "Pasang", "تثبيت", "ইনস্টল করুন",
  "इंस्टॉल करें", "ติดตั้ง", "安装", "安裝")
r("plan.relay.uninstall", "Uninstall relay",
  "Remove", "Remover", "Quitar", "Retirer", "Entfernen", "Удалить", "Kaldır", "Hapus", "إزالة", "সরান", "हटाएँ", "ลบ",
  "移除", "移除")

r("Koncluí Proxy key found (klaude)", "Koncluí Proxy key found (klaude)",
  "Connected through your Koncluí subscription", "Conectado pela sua assinatura Koncluí",
  "Conectado con tu suscripción de Koncluí", "Connecté via ton abonnement Koncluí", "Über dein Koncluí-Abo verbunden",
  "Подключено по вашей подписке Koncluí", "Koncluí aboneliğin üzerinden bağlı", "Terhubung lewat langganan Koncluí-mu",
  "متصل عبر اشتراك Koncluí", "Koncluí সাবস্ক্রিপশনের মাধ্যমে সংযুক্ত", "Koncluí सदस्यता से जुड़ा है",
  "เชื่อมต่อผ่านการสมัครสมาชิก Koncluí", "已通过你的 Koncluí 订阅连接", "已透過你的 Koncluí 訂閱連線")

s("konclui.voice.privacy.proxy",
  ("through the Koncluí Proxy", "through your subscription"), ("pelo Koncluí Proxy", "pela sua assinatura"),
  ("por el Koncluí Proxy", "con tu suscripción"), ("via le Koncluí Proxy", "via ton abonnement"),
  ("über den Koncluí Proxy", "über dein Abo"), ("через Koncluí Proxy", "по твоей подписке"),
  ("Koncluí Proxy üzerinden", "aboneliğin üzerinden"), ("lewat Koncluí Proxy", "lewat langgananmu"),
  ("عبر Koncluí Proxy", "عبر اشتراكك"), ("Koncluí Proxy দিয়ে", "তোমার সাবস্ক্রিপশন দিয়ে"),
  ("Koncluí Proxy से होकर", "तुम्हारी सदस्यता से होकर"), ("ผ่าน Koncluí Proxy", "ผ่านการสมัครสมาชิกของคุณ"),
  ("通过 Koncluí Proxy", "通过你的订阅"), ("透過 Koncluí Proxy", "透過你的訂閱"))

# "GOWA" is the gateway's own name: it stays under Details (UX.md glossary), never in the sentences of an install that failed.
# What happened, the impact, the next step.
r("whatsapp.install.bad-checksum", "The download doesn't match the file GOWA published: it was deleted, nothing was installed.",
  "The download doesn't match the file the gateway published: it was deleted and nothing was installed. Try again.",
  "O download não corresponde ao arquivo que o gateway publicou: foi apagado e nada foi instalado. Tente de novo.",
  "La descarga no coincide con el archivo publicado de la pasarela: se eliminó y no se instaló nada. Inténtalo de nuevo.",
  "Le téléchargement ne correspond pas au fichier publié de la passerelle : il a été supprimé, rien n'a été installé. Réessaie.",
  "Der Download stimmt nicht mit der veröffentlichten Gateway-Datei überein: Er wurde gelöscht, nichts wurde installiert. Versuche es erneut.",
  "Загрузка не совпадает с опубликованным файлом шлюза: она удалена, ничего не установлено. Попробуйте ещё раз.",
  "İndirilen dosya, ağ geçidinin yayımladığı dosyayla eşleşmiyor: silindi, hiçbir şey yüklenmedi. Yeniden dene.",
  "Unduhan tidak cocok dengan file yang dipublikasikan gateway: sudah dihapus, tidak ada yang dipasang. Coba lagi.",
  "التنزيل لا يطابق الملف المنشور للبوابة: حُذف ولم يُثبَّت شيء. حاول مرة أخرى.",
  "ডাউনলোড গেটওয়ের প্রকাশিত ফাইলের সঙ্গে মেলে না: মুছে ফেলা হয়েছে, কিছু ইনস্টল হয়নি। আবার চেষ্টা করুন।",
  "डाउनलोड गेटवे की प्रकाशित फ़ाइल से मेल नहीं खाता: हटा दिया गया, कुछ इंस्टॉल नहीं हुआ। फिर कोशिश करें।",
  "ไฟล์ที่ดาวน์โหลดไม่ตรงกับไฟล์ที่เกตเวย์เผยแพร่: ลบไฟล์แล้ว ไม่มีอะไรถูกติดตั้ง ลองอีกครั้ง",
  "下载内容与网关发布的文件不符：已删除，未安装任何内容。请重试。",
  "下載的檔案與閘道發布的檔案不符，已刪除檔案且未安裝任何內容。請再試一次。")

r("whatsapp.install.checking", "Looking for the latest GOWA…",
  "Looking for the latest gateway…", "Procurando a versão mais recente do gateway…",
  "Buscando la última versión de la pasarela…", "Recherche de la dernière version de la passerelle…",
  "Suche nach dem neuesten Gateway…", "Поиск последней версии шлюза…", "En son ağ geçidi sürümü aranıyor…",
  "Mencari gateway terbaru…", "البحث عن أحدث إصدار من البوابة…", "গেটওয়ের সর্বশেষ সংস্করণ খোঁজা হচ্ছে…",
  "गेटवे का नया वर्शन ढूँढ रहा है…", "กำลังค้นหาเกตเวย์เวอร์ชันล่าสุด…", "正在查找最新版网关…", "正在尋找最新版閘道…")

r("whatsapp.install.no-build", "No GOWA build for this Mac was found on GitHub. Try again later, or set your own gateway under Advanced.",
  "No gateway build for this Mac was found on GitHub. Try again later, or set your own gateway under Advanced.",
  "Não há versão do gateway para este Mac no GitHub. Tente mais tarde ou configure seu próprio gateway em Avançado.",
  "No hay ninguna versión de la pasarela para este Mac en GitHub. Inténtalo más tarde o configura tu propia pasarela en Avanzado.",
  "Aucune version de la passerelle pour ce Mac sur GitHub. Réessaie plus tard, ou configure ta propre passerelle dans Avancé.",
  "Auf GitHub wurde kein Gateway für diesen Mac gefunden. Versuche es später erneut oder richte unter „Erweitert“ dein eigenes Gateway ein.",
  "На GitHub нет сборки шлюза для этого Mac. Попробуйте позже или укажите свой шлюз в разделе «Дополнительно».",
  "GitHub'da bu Mac için ağ geçidi sürümü bulunamadı. Daha sonra yeniden dene ya da Gelişmiş bölümünde kendi ağ geçidini ayarla.",
  "Tidak ada versi gateway untuk Mac ini di GitHub. Coba lagi nanti, atau atur gateway sendiri di Lanjutan.",
  "لم يُعثر على إصدار للبوابة لهذا الـ Mac على GitHub. أعد المحاولة لاحقًا أو اضبط بوابتك في «متقدم».",
  "GitHub-এ এই Mac-এর জন্য গেটওয়ে পাওয়া যায়নি। পরে আবার চেষ্টা করুন, বা অ্যাডভান্সডে নিজের গেটওয়ে সেট করুন।",
  "GitHub पर इस Mac के लिए गेटवे नहीं मिला। बाद में फिर कोशिश करें, या एडवांस्ड में अपना गेटवे सेट करें।",
  "ไม่พบเกตเวย์สำหรับ Mac เครื่องนี้บน GitHub ลองอีกครั้งภายหลัง หรือตั้งค่าเกตเวย์ของคุณเองใน “ขั้นสูง”",
  "GitHub 上没有适用于此 Mac 的网关版本。请稍后重试，或在“高级”中设置你自己的网关。",
  "GitHub 上找不到適用於這台 Mac 的閘道版本。請稍後再試，或在「進階」設定自訂閘道。")

r("whatsapp.install.no-checksum", "GOWA's release has no checksum to check the download against: nothing was installed.",
  "The gateway's release has no checksum to check the download against: nothing was installed. Try again later.",
  "A versão do gateway não tem checksum para verificar o download: nada foi instalado. Tente mais tarde.",
  "La versión de la pasarela no tiene suma de comprobación para verificar la descarga: no se instaló nada. Inténtalo más tarde.",
  "La version de la passerelle n'a pas d'empreinte pour vérifier le téléchargement : rien n'a été installé. Réessaie plus tard.",
  "Die Gateway-Version hat keine Prüfsumme, um den Download zu überprüfen: Es wurde nichts installiert. Versuche es später erneut.",
  "У выпуска шлюза нет контрольной суммы для проверки: ничего не установлено. Попробуйте позже.",
  "Ağ geçidi sürümünde indirmeyi doğrulayacak bir sağlama toplamı yok: hiçbir şey yüklenmedi. Daha sonra yeniden dene.",
  "Rilis gateway tidak punya checksum untuk memeriksa unduhan: tidak ada yang dipasang. Coba lagi nanti.",
  "لا يحتوي إصدار البوابة على بصمة للتحقق من التنزيل: لم يُثبَّت شيء. أعد المحاولة لاحقًا.",
  "গেটওয়ে রিলিজে ডাউনলোড যাচাইয়ের চেকসাম নেই: কিছু ইনস্টল হয়নি। পরে আবার চেষ্টা করুন।",
  "गेटवे रिलीज़ में डाउनलोड जाँचने के लिए चेकसम नहीं है: कुछ इंस्टॉल नहीं हुआ। बाद में फिर कोशिश करें।",
  "รุ่นของเกตเวย์ไม่มีค่าตรวจสอบสำหรับยืนยันไฟล์ที่ดาวน์โหลด จึงไม่ได้ติดตั้งอะไร ลองอีกครั้งภายหลัง",
  "网关版本没有可用于校验的校验和：未安装任何内容。请稍后重试。",
  "閘道的發行版本未提供校驗碼，無法驗證下載檔案，因此未安裝任何內容。請稍後再試。")

# ---------------------------------------------------------------------------------------------
# Dashes (A1-17, A3-16, A2-25): every key that joined two sentences with " — ", in the 14 languages.

for _key in ("hooks.antigravity.installed", "hooks.codex.installed", "hooks.copilot.installed", "hooks.gemini.installed",
             "hooks.klaude.installed", "hooks.muse.installed", "hooks.outdated", "plugin.amp.installed",
             "plugin.opencode.installed", "portfolio.no-accounts", "status.codex-hooks-installed",
             "status.hooks-installed-claude", "status.klaude-hooks-installed", "status.local.no-models %@",
             "voice.pill-no-hooks", "Give me a sec — back to work in three seconds."):
    DASHES[_key] = "sentence"
for _key in ("chat.other-providers.title", "voice.ask-which-remove", "%@ — open Spotify"):
    DASHES[_key] = "colon"

# Russian uses the dash as grammar; the rulebook has none, so these sentences take a colon, a comma or a full stop.
s("update.error.not-coucou", None, None, None, None, None,
  ("Загрузка — не объявленная версия Koncluí.", "Загрузка не совпадает с объявленной версией Koncluí."),
  None, None, None, None, None, None, None, None)
s("flow.how %@", None, None, None, None, None, ("отпустите — слова", "отпустите: слова"), None, None, None, None, None, None, None, None)
s("flow.privacy", None, None, None, None, None,
  (" — прямо на устройстве, если Mac это поддерживает;", ", прямо на устройстве, если Mac это поддерживает;"),
  None, None, None, None, None, None, None, None)
s("hub.setup %@", None, None, None, None, None, ("отпустите — слова", "отпустите: слова"), None, None, None, None, None, None, None, None)
s("hub.snippets-empty", None, None, None, None, None, ("пару слов — получите", "пару слов, получите"), None, None, None, None, None,
  None, None, None)
s("hub.snippets-sub", None, None, None, None, None, ("диктовки — Koncluí", "диктовки: Koncluí"), None, None, None, None, None, None,
  None, None)
s("hub.stat.apps-empty", None, None, None, None, None, ("в приложении — оно появится здесь", "в приложении, и оно появится здесь"),
  None, None, None, None, None, None, None, None)
s("hub.style.polished-detail", None, None, None, None, None, ("абзацы — для писем", "абзацы, для писем"), None, None, None, None,
  None, None, None, None)
s("notes.setup-title", None, None, None, None, None, ("Одна загрузка — и без сети", "Одна загрузка, дальше без сети"), None, None,
  None, None, None, None, None, None)
s("Dictate (right-click to choose the language)", None, None, None, None, None,
  ("правый клик — выбрать язык", "правый клик: выбрать язык"), None, None, None, None, None, None, None, None)
s("voice.mac-voices-help", None, None, None, None, None, ("Ava — женский, Jamie — мужской", "Ava: женский, Jamie: мужской"),
  None, None, None, None, None, None, None, None)


# ---------------------------------------------------------------------------------------------
# Literals no catalog key can reach: a hard-coded English string in an upstream view. The new keys are in
# .scratch/konclui/u2/strings.json (scripts/konclui/add-strings.py), each rule is re-applied after a merge, and a rule whose
# line changed upstream is reported STALE.
_APP = "NotchBuddy/Sources/App/"

FIXED += [
    # A1-33: the sidebar's first group is named in the person's words, not "Flow" (Coucou's old product name).
    (_APP + "FlowHub.swift", 'HubSidebarHeader(text: "Flow")',
     'HubSidebarHeader(text: String(localized: "konclui.hub.section.flow"))'),
    # A1-45: three "Adicionar" buttons on two pages said the same word.
    (_APP + "FlowHubWords.swift", 'Button(String(localized: "hub.add"), action: addWord)',
     'Button(String(localized: "konclui.hub.add-word"), action: addWord)'),
    (_APP + "FlowHubWords.swift", 'Button(String(localized: "hub.add"), action: addReplacement)',
     'Button(String(localized: "konclui.hub.add-replacement"), action: addReplacement)'),
    (_APP + "FlowHubWords.swift",
     'Button(editing == nil ? String(localized: "hub.add") : String(localized: "hub.save"), action: save)',
     'Button(editing == nil ? String(localized: "konclui.hub.add-snippet") : String(localized: "hub.save"), action: save)'),
    # A1-44: a snippet's trigger was always in French guillemets.
    (_APP + "FlowHubWords.swift", 'Text("« \\(snippet.trigger) »")',
     'Text(String(format: String(localized: "konclui.hub.trigger-quoted %@"), snippet.trigger))'),
    # A1-12 (the label is hub.open): the button says "Abrir os ajustes do ditado", so it opens that page.
    (_APP + "FlowSettingsBox.swift", 'Button(String(localized: "hub.open")) { FlowHubController.shared.show() }',
     'Button(String(localized: "hub.open")) { FlowHubController.shared.show(.settings) }'),
    # The Notetaker's "download the models" notice opens the dictation settings page: its button is that label, not "Open Settings".
    (_APP + "NoteTaker.swift",
     'action: String(localized: "hub.open-settings"))) {\n                FlowHubController.shared.show(.settings)',
     'action: String(localized: "hub.open"))) {\n                FlowHubController.shared.show(.settings)'),
    # A1-31: the keycap names every key (the recorder's table stopped at letters and showed "·" for ] and [).
    (_APP + "SettingsView.swift", 'return map[c] ?? "·"', 'return map[c] ?? KoncluiKeyName.label(c)'),
    (_APP + "SettingsView.swift", 'Text(isRecording ? "Press keys…" : shortcutLabel)',
     'Text(isRecording ? String(localized: "konclui.key.press") : shortcutLabel)'),
    (_APP + "SettingsView.swift", 'return s.isEmpty ? "None" : s', 'return s.isEmpty ? String(localized: "None") : s'),
    (_APP + "ShortcutLogic.swift", 'return map[code] ?? "·"', 'return map[code] ?? KoncluiKeyName.label(code)'),
    # ShortcutLogic.swift now calls KoncluiKeyName: upstream's test compiles it with that file.
    ("scripts/test-shortcuts.sh", 'swiftc NotchBuddy/Sources/App/ShortcutLogic.swift \\\n',
     'swiftc NotchBuddy/Sources/App/ShortcutLogic.swift NotchBuddy/Sources/App/KoncluiKeyName.swift \\\n'),
    # A1-37: "⌘1 – ⌘9" is a range written with a dash.
    (_APP + "ShortcutLogic.swift", '("⌘1 – ⌘9",', '("⌘1 … ⌘9",'),
    # A3-12: the Codex gauge in the notch spoke English in every language; the Claude gauge already has these keys.
    (_APP + "CodexPlanGauge.swift", 'GaugeRowView(label: "5 hours", window: usage?.fiveHour, now: now)',
     'GaugeRowView(label: String(localized: "plan.5hours"), window: usage?.fiveHour, now: now)'),
    (_APP + "CodexPlanGauge.swift", 'GaugeRowView(label: "Week", window: usage?.sevenDay, now: now, weekly: true)',
     'GaugeRowView(label: String(localized: "plan.week"), window: usage?.sevenDay, now: now, weekly: true)'),
    (_APP + "CodexPlanGauge.swift", 'guard let usage else { return "Asking Codex…" }',
     'guard let usage else { return String(localized: "konclui.codex.asking") }'),
    (_APP + "CodexPlanGauge.swift", 'return plan + "just now"', 'return plan + String(localized: "plan.just-now")'),
    (_APP + "CodexPlanGauge.swift", 'return plan + "\\(mins) min ago"',
     'return plan + String(format: String(localized: "plan.mins-ago %lld"), Int64(mins))'),
    (_APP + "CodexPlanGauge.swift", 'return plan + "\\(mins / 60) h ago"',
     'return plan + String(format: String(localized: "plan.hours-ago %lld"), Int64(mins / 60))'),
    (_APP + "CodexPlanGauge.swift", 'var text = "\\(count) available"',
     'var text = String(format: String(localized: "konclui.codex.available %lld"), Int64(count))'),
    (_APP + "CodexPlanGauge.swift", 'text += " · until \\(resetExpiryFormatter.string(from: exp))"',
     'text += String(format: String(localized: "konclui.codex.until %@"), resetExpiryFormatter.string(from: exp))'),
]

# Leftovers of the pass: French guillemets in languages that do not use them, the Settings word in a message about Integrations.
s("konclui.whatsapp.update-failed.impact", None,
  ("«Atualizar gateway»", "“Atualizar gateway”"), None, None, None, None, ("«Ağ geçidini güncelle»", "“Ağ geçidini güncelle”"),
  ("«Perbarui gateway»", "“Perbarui gateway”"), None, ("«গেটওয়ে আপডেট করুন»", "“গেটওয়ে আপডেট করুন”"),
  ("«गेटवे अपडेट करें»", "“गेटवे अपडेट करें”"), ("«อัปเดตเกตเวย์»", "“อัปเดตเกตเวย์”"), None, None)
s("portfolio.error.no-creds", ("Add them in Settings.", "Add them in Integrations."),
  ("Adicione nas Configurações.", "Adicione em Integrações."), None, None, None, None, None, None, None, None, None, None, None, None)
DASHES["portfolio.instructions.okx"] = "sentence"
DASHES["%@: %@"] = "colon"


# ---------------------------------------------------------------------------------------------
# WhatsApp: the keys of the old block, which the notch card, the status lines and the installer still use, were never written in
# German, Thai and Turkish, so those three languages read English (A3-12). FILL never overwrites upstream.
f("whatsapp.advanced", "Erweitert: dein eigenes Gateway", "ขั้นสูง: เกตเวย์ของคุณเอง", "Gelişmiş: kendi ağ geçidin")
f("whatsapp.install", "WhatsApp installieren", "ติดตั้ง WhatsApp", "WhatsApp'ı kur")
f("whatsapp.install.download-failed", "Der Download hat nicht geklappt. Prüfe deine Verbindung und versuche es erneut.",
  "ดาวน์โหลดไม่สำเร็จ ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง", "İndirme tamamlanamadı. Bağlantını kontrol edip yeniden dene.")
f("whatsapp.install.downloading %lld", "Wird heruntergeladen (%lld MB)…", "กำลังดาวน์โหลด (%lld MB)…", "İndiriliyor (%lld MB)…")
f("whatsapp.install.hint",
  "Koncluí lädt GOWA, das Open-Source-Gateway, von seiner GitHub-Seite herunter (etwa 15 MB, einmalig), prüft es und startet es. Scanne danach den QR-Code mit deinem Handy. Kein Terminal nötig.",
  "Koncluí ดาวน์โหลด GOWA เกตเวย์โอเพนซอร์สจากหน้า GitHub (ประมาณ 15 MB ครั้งเดียว) ตรวจสอบและเริ่มทำงาน จากนั้นสแกนคิวอาร์โค้ดด้วยโทรศัพท์ ไม่ต้องใช้ Terminal",
  "Koncluí, açık kaynaklı ağ geçidi GOWA'yı GitHub sayfasından indirir (yaklaşık 15 MB, tek seferlik), doğrular ve başlatır. Ardından QR kodunu telefonunla tara. Terminal gerekmez.")
f("whatsapp.install.installing", "Wird installiert und gestartet…", "กำลังติดตั้งและเริ่มทำงาน…", "Kuruluyor ve başlatılıyor…")
f("whatsapp.install.ready %@", "Gateway GOWA %@ installiert, von Koncluí gestartet", "ติดตั้งเกตเวย์ GOWA %@ แล้ว เริ่มโดย Koncluí",
  "GOWA ağ geçidi %@ kuruldu, Koncluí başlattı")
f("whatsapp.install.ready-custom", "Dein GOWA-Gateway ist eingerichtet", "ตั้งค่าเกตเวย์ GOWA ของคุณแล้ว", "GOWA ağ geçidin ayarlandı")
f("whatsapp.install.unzip-failed", "Der Download konnte nicht entpackt werden. Versuche es erneut.",
  "คลายไฟล์ที่ดาวน์โหลดไม่ได้ ลองอีกครั้ง", "İndirilen dosya açılamadı. Yeniden dene.")
f("whatsapp.install.update", "Aktualisieren", "อัปเดต", "Güncelle")
f("whatsapp.save", "WhatsApp sichern", "บันทึก WhatsApp", "WhatsApp'ı kaydet")
f("whatsapp.autostart", "GOWA automatisch starten", "เริ่ม GOWA อัตโนมัติ", "GOWA'yı otomatik başlat")
f("whatsapp.autostart.hint",
  "Koncluí führt es nur auf diesem Mac aus (127.0.0.1, der Port der URL), ohne Medien herunterzuladen, und beendet es, wenn Koncluí beendet wird. Seine WhatsApp-Sitzung liegt in ~/Library/Application Support/Konclui/GOWA.",
  "Koncluí เรียกใช้งานเฉพาะบน Mac เครื่องนี้ (127.0.0.1 พอร์ตตาม URL) โดยไม่ดาวน์โหลดสื่อ และหยุดเมื่อ Koncluí ปิด เซสชัน WhatsApp ของมันอยู่ใน ~/Library/Application Support/Konclui/GOWA",
  "Koncluí onu yalnızca bu Mac'te çalıştırır (127.0.0.1, URL'nin bağlantı noktası), medya indirmez ve Koncluí kapanınca durdurur. WhatsApp oturumu ~/Library/Application Support/Konclui/GOWA içinde kalır.")
f("whatsapp.autostart.path", "Pfad zur GOWA-Binärdatei (whatsapp)", "พาธของไบนารี GOWA (whatsapp)", "GOWA ikili dosyasının yolu (whatsapp)")
f("whatsapp.choose", "Auswählen…", "เลือก…", "Seç…")
f("whatsapp.mark-read-on-open", "Als gelesen markieren, wenn ich eine Unterhaltung öffne",
  "ทำเครื่องหมายว่าอ่านแล้วเมื่อฉันเปิดการสนทนา", "Bir sohbeti açtığımda okundu olarak işaretle")
f("whatsapp.mark-read.hint", "Aus: Nur als gelesen markiert, wenn du antwortest. Nie, wenn eine Nachricht nur ankommt.",
  "ปิด: ทำเครื่องหมายว่าอ่านแล้วเฉพาะตอนที่คุณตอบกลับ ไม่ทำเมื่อข้อความเพิ่งเข้ามา",
  "Kapalı: yalnızca yanıtladığında okundu işaretlenir. Mesaj sadece geldiği için asla.")
f("whatsapp.reply.placeholder", "Antworten…  (⇧↩ neue Zeile)", "ตอบกลับ…  (⇧↩ ขึ้นบรรทัดใหม่)", "Yanıtla…  (⇧↩ yeni satır)")
f("whatsapp.reply.too-fast", "Höchstens ein paar Antworten pro Minute: Warte einen Moment.",
  "ตอบได้ไม่กี่ครั้งต่อนาที โปรดรอสักครู่", "Dakikada en fazla birkaç yanıt: biraz bekle.")
f("whatsapp.reply.too-long", "Zu lang für eine Nachricht (höchstens 4.096 Zeichen).",
  "ยาวเกินไปสำหรับหนึ่งข้อความ (สูงสุด 4,096 ตัวอักษร)", "Tek mesaj için çok uzun (en fazla 4.096 karakter).")
f("whatsapp.add", "Hinzufügen", "เพิ่ม", "Ekle")
f("whatsapp.connected-as %@", "Verbunden als %@", "เชื่อมต่อในชื่อ %@", "%@ olarak bağlı")
f("whatsapp.credential.gowa", "Basic Auth  (Benutzer:Passwort, falls gesetzt)", "Basic auth  (ผู้ใช้:รหัสผ่าน ถ้ามี)",
  "Temel kimlik doğrulama  (kullanıcı:parola, varsa)")
f("whatsapp.credential.openwa", "API-Schlüssel  (owa_k1_…)", "คีย์ API  (owa_k1_…)", "API anahtarı  (owa_k1_…)")
f("whatsapp.empty", "Keine neuen Nachrichten", "ไม่มีข้อความใหม่", "Yeni mesaj yok")
f("whatsapp.enable", "Meine WhatsApp-Nachrichten anzeigen", "แสดงข้อความ WhatsApp ของฉัน", "WhatsApp mesajlarımı göster")
f("whatsapp.focus-unavailable",
  "macOS lässt diese Version von Koncluí den Fokus-Status noch nicht lesen: Nachrichten kommen trotzdem an, Koru reagiert weiter.",
  "macOS ยังไม่อนุญาตให้ Koncluí รุ่นนี้อ่านสถานะโฟกัส ข้อความยังเข้ามาตามปกติ และ Koru ยังคงตอบสนอง",
  "macOS bu Koncluí sürümünün Odak durumunu okumasına henüz izin vermiyor: mesajlar yine gelir, Koru tepki vermeye devam eder.")
f("whatsapp.gateway", "Gateway", "เกตเวย์", "Ağ geçidi")
f("whatsapp.ignore-chat", "Diese Unterhaltung ignorieren", "เพิกเฉยต่อแชตนี้", "Bu sohbeti yoksay")
f("whatsapp.ignore-placeholder", "Zu ignorierende Telefonnummer oder Chat-ID", "หมายเลขโทรศัพท์หรือรหัสแชตที่จะเพิกเฉย",
  "Yok sayılacak telefon numarası veya sohbet kimliği")
f("whatsapp.ignored", "Ignorierte Unterhaltungen", "แชตที่เพิกเฉย", "Yok sayılan sohbetler")
f("whatsapp.media.contact", "Kontakt", "รายชื่อติดต่อ", "Kişi")
f("whatsapp.media.document", "Dokument", "เอกสาร", "Belge")
f("whatsapp.media.location", "Standort", "ตำแหน่งที่ตั้ง", "Konum")
f("whatsapp.media.other", "Nachricht", "ข้อความ", "Mesaj")
f("whatsapp.media.photo", "Foto", "รูปภาพ", "Fotoğraf")
f("whatsapp.media.sticker", "Sticker", "สติกเกอร์", "Çıkartma")
f("whatsapp.media.video", "Video", "วิดีโอ", "Video")
f("whatsapp.media.voice", "Sprachnachricht", "ข้อความเสียง", "Sesli mesaj")
f("whatsapp.mute-groups", "Gruppen stummschalten (außer ich werde erwähnt)", "ปิดเสียงกลุ่ม (ยกเว้นเมื่อมีการกล่าวถึงฉัน)",
  "Grupları sessize al (bahsedilmediğim sürece)")
f("whatsapp.no-slot", "Mache in „Aktive Pills“ Platz, um die WhatsApp-Pill anzuzeigen (höchstens 4).",
  "เว้นที่ใน “แถบที่ใช้งาน” เพื่อแสดงแถบ WhatsApp (สูงสุด 4)",
  "WhatsApp aracını göstermek için Etkin araçlar'da yer aç (en fazla 4).")
f("whatsapp.port", "Webhook-Port von Koncluí", "พอร์ตเว็บฮุกของ Koncluí", "Koncluí'nin webhook bağlantı noktası")
f("whatsapp.privacy",
  "Koncluí spricht nur mit dem Gateway auf diesem Mac. Nachrichten bleiben im Arbeitsspeicher, werden nie protokolliert oder gespeichert und beim Beenden von Koncluí vergessen. Fotos oder Medien werden nie heruntergeladen.",
  "Koncluí สื่อสารเฉพาะกับเกตเวย์บน Mac เครื่องนี้ ข้อความอยู่ในหน่วยความจำ ไม่ถูกบันทึกหรือเก็บถาวร และจะถูกลืมเมื่อ Koncluí ปิด ไม่มีการดาวน์โหลดรูปภาพหรือสื่อใด ๆ",
  "Koncluí yalnızca bu Mac'teki ağ geçidiyle konuşur. Mesajlar bellekte kalır, asla günlüğe yazılmaz veya kaydedilmez ve Koncluí kapanınca unutulur. Hiçbir fotoğraf veya medya indirilmez.")
f("whatsapp.qr.hint", "Auf deinem Handy: WhatsApp › Einstellungen › Verknüpfte Geräte › Gerät verknüpfen, dann scanne diesen Code.",
  "บนโทรศัพท์ของคุณ: WhatsApp › การตั้งค่า › อุปกรณ์ที่เชื่อมโยง › เชื่อมโยงอุปกรณ์ แล้วสแกนโค้ดนี้",
  "Telefonunda: WhatsApp › Ayarlar › Bağlı cihazlar › Cihaz bağla, sonra bu kodu tara.")
f("whatsapp.respect-focus", "Während eines Fokus still bleiben", "เงียบระหว่างที่เปิดโฟกัส", "Odak sırasında sessiz kal")
f("whatsapp.status.bad-url", "Die Gateway-URL ist ungültig (http://…)", "URL ของเกตเวย์ไม่ถูกต้อง (http://…)",
  "Ağ geçidi URL'si geçerli değil (http://…)")
f("whatsapp.status.connected", "Verbunden", "เชื่อมต่อแล้ว", "Bağlı")
f("whatsapp.status.connecting", "Verbindung zum Gateway wird hergestellt…", "กำลังเชื่อมต่อกับเกตเวย์…", "Ağ geçidine bağlanılıyor…")
f("whatsapp.status.unauthorized", "Das Gateway lehnt die Zugangsdaten ab", "เกตเวย์ปฏิเสธข้อมูลรับรอง",
  "Ağ geçidi kimlik bilgilerini reddediyor")
f("whatsapp.status.unreachable", "Das Gateway antwortet nicht: Läuft es?", "เกตเวย์ไม่ตอบสนอง กำลังทำงานอยู่หรือไม่",
  "Ağ geçidi yanıt vermiyor: çalışıyor mu?")
f("whatsapp.test", "Verbindung testen", "ทดสอบการเชื่อมต่อ", "Bağlantıyı test et")
f("whatsapp.test.connected %@", "Verbunden als %@.", "เชื่อมต่อในชื่อ %@", "%@ olarak bağlı.")
f("whatsapp.test.connecting", "Das Gateway antwortet und verbindet sich mit WhatsApp…",
  "เกตเวย์ตอบสนองและกำลังเชื่อมต่อกับ WhatsApp…", "Ağ geçidi yanıt veriyor ve WhatsApp'a bağlanıyor…")
f("whatsapp.test.needs-qr", "Das Gateway antwortet. Scanne den QR-Code unten mit deinem Handy.",
  "เกตเวย์ตอบสนอง สแกนคิวอาร์โค้ดด้านล่างด้วยโทรศัพท์ของคุณ", "Ağ geçidi yanıt veriyor. Aşağıdaki QR kodunu telefonunla tara.")
f("whatsapp.title", "WhatsApp (experimentell)", "WhatsApp (ทดลอง)", "WhatsApp (deneysel)")
f("whatsapp.warning",
  "Inoffizielle Integration: Sie läuft über ein Gateway, das du auf diesem Mac betreibst. Nutze sie nur mit deinem eigenen Konto. WhatsApp kann Konten einschränken, die sie missbrauchen.",
  "การเชื่อมต่อที่ไม่เป็นทางการ: ทำงานผ่านเกตเวย์ที่คุณรันบน Mac เครื่องนี้ ใช้กับบัญชีของคุณเองเท่านั้น WhatsApp อาจจำกัดบัญชีที่ใช้ในทางที่ผิด",
  "Resmî olmayan entegrasyon: Bu Mac'te çalıştırdığın bir ağ geçidi üzerinden gider. Yalnızca kendi hesabında kullan. WhatsApp, kötüye kullanan hesapları kısıtlayabilir.")
f("whatsapp.webhook.live", "Live: Neue Nachrichten kommen sofort an.", "สด: ข้อความใหม่เข้ามาทันที", "Canlı: yeni mesajlar hemen gelir.")
f("whatsapp.webhook.polling", "Neue Nachrichten werden alle 20 s abgefragt.", "ตรวจหาข้อความใหม่ทุก 20 วินาที",
  "Yeni mesajlar 20 sn'de bir kontrol ediliyor.")
f("whatsapp.webhook.port-busy %lld", "Port %lld ist belegt: Wähle einen anderen. Bis dahin wird alle 20 s abgefragt.",
  "พอร์ต %lld ถูกใช้งานอยู่ โปรดเลือกพอร์ตอื่น ระหว่างนี้จะตรวจหาทุก 20 วินาที",
  "%lld numaralı bağlantı noktası dolu: başka birini seç. Bu arada 20 sn'de bir kontrol ediliyor.")
f("whatsapp.webhook.refused %@", "Das Gateway hat die Adresse von Koncluí abgelehnt (%@). Stattdessen wird alle 20 s abgefragt.",
  "เกตเวย์ปฏิเสธที่อยู่ของ Koncluí (%@) จะตรวจหาทุก 20 วินาทีแทน",
  "Ağ geçidi Koncluí'nin adresini reddetti (%@). Bunun yerine 20 sn'de bir kontrol ediliyor.")
f("whatsapp.you", "Du", "คุณ", "Sen")

# "Flow" is Coucou's old name for the dictation feature (A1-33): the What's new stat says what it is.
r("whatsnew.stat.saved", "Saved with Flow",
  "Saved by dictation", "Economizado com o ditado", "Ahorrado con el dictado", "Gagné grâce à la dictée", "Durch Diktat gespart",
  "Сэкономлено диктовкой", "Dikteyle kazanılan", "Dihemat dengan dikte", "وفّرته بفضل الإملاء", "ডিক্টেশনে বাঁচানো",
  "डिक्टेशन से बचा समय", "ประหยัดด้วยการป้อนข้อความด้วยเสียง", "听写帮你节省", "聽寫幫你節省")

# Two English-only strings that show: the notch's upload card ("name is ready.") and a crypto address label.
fill("%@ is ready.", "%@ is ready.", "%@ está pronto.", "%@ está listo.", "%@ est prêt.", "%@ ist bereit.", "%@ готов.",
     "%@ hazır.", "%@ siap.", "%@ جاهز.", "%@ প্রস্তুত।", "%@ तैयार है।", "%@ พร้อมแล้ว", "%@ 已就绪。")
fill("Address", "Address", "Endereço", "Dirección", "Adresse", "Adresse", "Адрес", "Adres", "Alamat", "العنوان", "ঠিকানা",
     "पता", "ที่อยู่", "地址")
