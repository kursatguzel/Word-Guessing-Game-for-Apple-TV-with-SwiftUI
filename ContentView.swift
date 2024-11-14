import SwiftUI
import AVFoundation

// JSON'dan alınacak veri modelini tanımlıyoruz
struct Question: Codable {
    let kelime: String
    let ipucu: String
}

struct ContentView: View {
    @State private var questions: [Question] = []
    @State private var currentQuestionIndex = 0
    @State private var word = ""
    @State private var displayedWord = [String]()
    @State private var correctLetters = Set<Character>()
    @State private var wrongAttempts = 0
    @State private var score = 0
    @State private var hint = ""
    @State private var selectedLetters = Set<String>()  // Seçilen harfler
    @State private var backgroundColor: Color = .white // Arka plan rengi
    @State private var timeLeft: Int = 0 // Kalan süre
    @State private var timer: Timer? // Zamanlayıcı
    @State private var isGameOver: Bool = false // Oyun bitti mi?

    let letterOptions = [
        ["A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ"],
        ["H", "I", "İ", "J", "K", "L", "M", "N", "O"],
        ["Ö", "P", "R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z"]
    ]
    
    let backgroundColors: [Color] = [
        .red, .green, .blue, .yellow, .purple, .orange
    ]
    
    var applauseSound: AVAudioPlayer? // Alkış sesi için AVAudioPlayer
    var backgroundMusicPlayer: AVAudioPlayer? // Arka plan müziği için AVAudioPlayer
    var warningSound: AVAudioPlayer? // Uyarı sesi için AVAudioPlayer
    
    @State private var isMuted = false // Ses durumu (sessiz veya sesli)
    
    init() {
        _word = State(initialValue: "")
        _hint = State(initialValue: "")
        _displayedWord = State(initialValue: [])
        
        // Alkış sesini yükleme
        if let applauseURL = Bundle.main.url(forResource: "applause", withExtension: "mp3") {
            do {
                applauseSound = try AVAudioPlayer(contentsOf: applauseURL)
            } catch {
                print("Alkış ses dosyası bulunamadı.")
            }
        }
        
        // Arka plan müziğini yükleme
        if let musicURL = Bundle.main.url(forResource: "background_music", withExtension: "mp3") {
            do {
                backgroundMusicPlayer = try AVAudioPlayer(contentsOf: musicURL)
                backgroundMusicPlayer?.numberOfLoops = -1
                backgroundMusicPlayer?.prepareToPlay()
            } catch {
                print("Müzik dosyası bulunamadı.")
            }
        }
        
        // Uyarı sesini yükleme
        if let warningURL = Bundle.main.url(forResource: "warning", withExtension: "mp3") {
            do {
                warningSound = try AVAudioPlayer(contentsOf: warningURL)
            } catch {
                print("Uyarı ses dosyası bulunamadı.")
            }
        }
    }
    
    var body: some View {
        VStack {
            Text("Kelime: \(displayedWord.joined(separator: " "))")
                .font(.title)
                .padding()
            
            Text("İpucu: \(hint)")
                .font(.system(size: 40)) // 20 px boyutunda bir font
                .padding()

            Text("Kalan Süre: \(timeLeft) saniye")
                .font(.title)
                .padding()
            
            VStack {
                ForEach(letterOptions, id: \.self) { block in
                    HStack {
                        ForEach(block, id: \.self) { letter in
                            Button(action: {
                                self.checkGuess(letter)
                            }) {
                                Text(letter)
                                    .frame(width: 40, height: 40)
                                    .background(selectedLetters.contains(letter) ? Color.gray : buttonBackgroundColor)
                                    .foregroundColor(selectedLetters.contains(letter) ? .gray : buttonForegroundColor)
                                    .cornerRadius(8)
                                    .padding(4)
                            }
                            .disabled(selectedLetters.contains(letter))
                        }
                    }
                    .padding(.bottom, 3)
                }
            }
            
            Text("Puan: \(score)")
                .font(.title)
                .padding()

            Text("Yanlış Tahminler: \(wrongAttempts)")
                .font(.subheadline)
            
            Spacer()
            
            Button(action: {
                self.toggleMute()
            }) {
                HStack {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.3.fill")
                        .foregroundColor(.white)
                    Text(isMuted ? "Ses Aç" : "Ses Kapat")
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .onAppear(perform: resetGame)
        .onAppear {
            if !isMuted {
                backgroundMusicPlayer?.play()
            }
        }
        .background(backgroundColor)
        .edgesIgnoringSafeArea(.all)
        .alert(isPresented: $isGameOver) {
            Alert(title: Text("Oyun Bitti"), message: Text("Puanınız: \(score)"), dismissButton: .default(Text("Tamam")) {
                resetGame() // Oyun sona erdiğinde, yeniden başlatılacak
            })
        }
    }
    
    func toggleMute() {
        isMuted.toggle()
        
        if isMuted {
            backgroundMusicPlayer?.stop()
            applauseSound?.stop()
            warningSound?.stop() // Uyarı sesini durdur
        } else {
            backgroundMusicPlayer?.play()
        }
    }
    
    func checkGuess(_ letter: String) {
        guard !selectedLetters.contains(letter) else { return }
        
        selectedLetters.insert(letter)
        
        if word.contains(letter) {
            for (index, char) in word.enumerated() {
                if String(char) == letter {
                    displayedWord[index] = letter
                    correctLetters.insert(char)
                }
            }
            score += 10
            
            if !displayedWord.contains("_") {
                playApplauseSound()
                nextQuestion()
            }
        } else {
            wrongAttempts += 1
            score -= 10
        }
    }
    
    func playApplauseSound() {
        if !isMuted {
            applauseSound?.play()
        }
    }
    
    func nextQuestion() {
        if !questions.isEmpty {
            currentQuestionIndex += 1
            if currentQuestionIndex < questions.count {
                let newQuestion = questions[currentQuestionIndex]
                word = newQuestion.kelime
                hint = newQuestion.ipucu
                
                displayedWord = word.map { $0 == " " ? " " : "_" }
                correctLetters.removeAll()
                wrongAttempts = 0
                
                selectedLetters.removeAll()
                backgroundColor = backgroundColors.randomElement() ?? .white
                startTimer() // Yeni kelime için zaman başlat
            } else {
                questions.shuffle() // Soruları karıştır
                currentQuestionIndex = 0
                resetGame() // Yeniden başlat
            }
        }
    }
    
    func resetGame() {
        loadQuestions() // Soruları JSON'dan yükle
        questions.shuffle() // Soruları karıştırıyoruz
        currentQuestionIndex = 0
        if let firstQuestion = questions.first {
            word = firstQuestion.kelime
            hint = firstQuestion.ipucu
            displayedWord = word.map { $0 == " " ? " " : "_" }
            correctLetters.removeAll()
            wrongAttempts = 0
            score = 0
            selectedLetters.removeAll()
            backgroundColor = backgroundColors.randomElement() ?? .white
            startTimer() // İlk kelime için zaman başlat
        }
    }
    
    // JSON'dan soruları yüklemek
    func loadQuestions() {
        if let url = Bundle.main.url(forResource: "Sorular", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let loadedQuestions = try JSONDecoder().decode([Question].self, from: data)
                self.questions = loadedQuestions
            } catch {
                print("Sorular yüklenirken hata oluştu: \(error)")
            }
        }
    }
    
    // Timer'ı başlatma fonksiyonu
    func startTimer() {
        timeLeft = word.count * 5
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if self.timeLeft > 0 {
                self.timeLeft -= 1
                if self.timeLeft <= 10 && self.timeLeft > 0 {
                    self.playWarningSound() // Son 10 saniye kaldığında uyarı sesi çalsın
                }
            } else {
                self.endGame() // Süre bittiğinde oyun sona erer
            }
        }
    }
    
    // Uyarı sesini çal
    func playWarningSound() {
        if !isMuted {
            warningSound?.play()
        }
    }
    
    // Oyun sona erdiğinde çalışacak fonksiyon
    func endGame() {
        timer?.invalidate() // Timer'ı durdur
        warningSound?.stop() // Uyarı sesini durdur
        isGameOver = true // Oyun bitti
    }
    
    var buttonBackgroundColor: Color {
        return backgroundColor == .white ? .blue : .white
    }
    
    var buttonForegroundColor: Color {
        return backgroundColor == .white ? .white : .black
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
