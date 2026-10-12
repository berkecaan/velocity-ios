# Velocity — iPhone GPS hız göstergesi

SwiftUI ile geliştirilmiş iOS 17+ uygulaması. iPhone 16 Pro Max ve diğer iPhone boyutlarına uyum sağlar. Portre ve yatay ekran; neon yeşil, buz mavisi ve amber temaları; büyük dijital gösterge; aynalı HUD; km/h ve mph; seçilen hız sınırında titreşim; son 90 ölçüm grafiği; mesafe, hareket ortalaması ve maksimum hız; cihazda saklanan sürüş geçmişi; Apple haritası ve CSV dışa aktarma.

## GitHub'dan IPA

1. `velocity-ios` adında yeni bir depo oluşturun; bu klasörün **içeriğini**, `.github` dahil, `main` dalının köküne gönderin.
2. Actions → Build downloadable IPA derlemesini bekleyin.
3. Başarılı derlemeden sonra Releases bölümünden `Velocity-unsigned.ipa` dosyasını indirin. Actions içinde de `Velocity-IPA` ZIP'i bulunur.
4. Bu paket **imzasızdır**. GBox veya kullandığınız imzalayıcıda kendi geçerli sertifikanızla imzalayıp yükleyin. `.sha256` dosyası doğrulama özetidir; yüklemeniz gerekmez.
5. Uygulamaya kesin konum izni verin ve açık havada GPS sinyalini bekleyin.

Derleme otomatik olarak simülatörde birim testlerini çalıştırır, iPhone uygulamasını derler ve IPA'yı release olarak yayımlar. Derleme başarısızsa release oluşturulmaz. Mac olmadan GitHub Actions kullanılabilir. Depo erişimi, Actions kullanım hakkı ve iş akışlarının etkin olması gerekir.

## Mac'te geliştirme

```sh
brew install xcodegen
xcodegen generate
open Velocity.xcodeproj
```

Xcode'da Velocity şemasını seçin. Yerel cihaz kurulumu için Signing & Capabilities bölümünde kendi Apple takımınızı seçin.

## Ölçüm ve gizlilik

- Core Location'ın hız verisi kullanılır. Negatif/bilinmeyen hız, 5 saniyeden eski veya düşük doğruluklu ölçüm kabul edilmez. Sinyal kaybında eski hız yerine `—` gösterilir.
- Uzun ölçüm boşlukları ve GPS konum sıçramaları mesafeye eklenmez. Hareket ortalaması = kabul edilen mesafe / hareket süresi.
- Yolun gerçek hız sınırı otomatik tespit edilmez; sınırı kullanıcı belirler.
- Uygulama arka plana alındığında sürüş bitirilip kaydedilir. Arka plan takibi yoktur. Ekran açık tutma seçeneği vardır.
- Rota 5 saniyede bir ve en fazla 20.000 nokta saklar. Hız grafiği en son 90 geçerli ölçümü tutar.
- Konum ve geçmiş yalnızca cihazda tutulur. CSV paylaşımını kullanıcı başlatır. Apple haritası internet kullanır; hız ölçümü için internet gerekmez.
- GPS araç göstergesinin yerine geçmez. HUD yalnızca ekranı aynalar; yansıma cama ve ışığa bağlıdır.

## Doğrulama durumu

Kaynak ve yapılandırma dosyaları hazırlanmıştır. İlk macOS/Xcode derlemesi GitHub Actions üzerinde çalıştırılmalı; gerçek iPhone GPS, yerleşim ve GBox kurulumu cihazda doğrulanmalıdır. Bu kaynak ZIP'i bir IPA değildir.
