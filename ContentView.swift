//
//  ContentView.swift
//  LogosBlue
//
//  Created by Daniel Rix-Perez on 23/07/2024.
//

import Foundation
import SwiftUI
import AVFoundation
//import MessageUI


class ChatGPTAPI {
    
    private let apiKey: String
    private let model: String
    private let maxTokens : Int = 4096
    //    different models have different costs
    public var historyList = [Message]()
    //    An array of all Messages with role, content attributes exchanged between the API endpoint and user device
    private let urlSession = URLSession.shared
    private let systemMessage: Message
    //    an initial prompt describing GPT's position in the chat
    public var conversationPath : URL = URL(string: "https://www.example.com")!
    public var audioFileNumber :Int=0
    
    init(apiKey: String, model: String = "gpt-3.5-turbo", systemPrompt: String = "You are a helpful assistant") {
        self.apiKey = apiKey
        self.model = model
        self.systemMessage = .init(role: "system", content: systemPrompt)
        self.conversationPath = FileManager.default.temporaryDirectory
    }
    
    //    formatted request including request type,method,endpoint,key
    private var chatUrlRequest: URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var chatUrlRequest = URLRequest(url: url)
        chatUrlRequest.httpMethod = "POST"
        chatUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        chatUrlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return chatUrlRequest
    }
    
    private var audioUrlRequest: URLRequest {
        let url = URL(string: "https://api.openai.com/v1/audio/speech")!
        var audioUrlRequest = URLRequest(url:url)
        audioUrlRequest.httpMethod = "POST"
        audioUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        audioUrlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return audioUrlRequest
    }
    
    private var transcriptionUrlRequest: URLRequest{
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var transcriptionUrlRequest = URLRequest(url:url)
        transcriptionUrlRequest.httpMethod = "POST"
        transcriptionUrlRequest.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")
        transcriptionUrlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorisation")
        return transcriptionUrlRequest
    }
    
    //    joins system messsage, chat history and prompt
    private func generateMessages(from text: String) -> [Message] {
        return [systemMessage] + historyList + [Message(role: "user", content: text)]
    }
    
    //    parses json response into string
    private func chatJsonBody(text: String) throws -> Data {
        let request = ChatRequest(model: model, messages: generateMessages(from: text),max_tokens:maxTokens)
        return try JSONEncoder().encode(request)
    }
    
    private func audioJsonBody(text: String, voice: String) -> Data? {
        let request = AudioRequest(model: "tts-1-hd", input: text, voice: voice)
        do {
            let jsonBody = try JSONEncoder().encode(request)
            print("JSON Body: \(String(data: jsonBody, encoding: .utf8)!)")
            return jsonBody
        } catch {
            print("Error encoding JSON: \(error)")
            return nil
        }
    }
    
//        private func transcriptJsonBody(file:File) --> Data{
//    let request = TranscriptionRequest(file:File,model:String,response_format:String)
//    return try JSONEncoder().encode(request)
//}
    
    private func appendToHistoryList(userText: String, responseText: String) {
        historyList.append(.init(role: "user", content: userText))
        historyList.append(.init(role: "assistant", content: responseText))
    }
    
//  uses previous functions to create a query,send it to the endpoint and return the response as a string
    func sendChatMessage(_ text: String, record:Bool) async throws -> String {
        var chatUrlRequest = self.chatUrlRequest
        chatUrlRequest.httpBody = try chatJsonBody(text: text)
        
        let (data, response) = try await urlSession.data(for: chatUrlRequest)
        
//        check for erroneous response
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            return "Bad response"
        }
        
//        parse responsse
        let completionResponse = try JSONDecoder().decode(CompletionResponse.self, from: data)
        let responseText = completionResponse.choices.first?.message.content ?? ""
        if record{
            appendToHistoryList(userText: text, responseText: responseText)
        }
        return responseText
    }
    
    func sendAudioRequest(_ content:String, voice:String, fileNumber : Int) async throws{
        var audioUrlRequest = self.audioUrlRequest
        audioUrlRequest.httpBody = try audioJsonBody(text: content, voice: voice)
        
        let (data, response) = try await urlSession.data(for: audioUrlRequest)
        
        print("data:", data,"response: ",response)
        
//        check for erroneous response
        if let httpResponse = response as? HTTPURLResponse {
            if 200...299 ~= httpResponse.statusCode {
                // Handle successful response
                print("Audio call successful")
            } else {
                // Handle error response
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("Error response body: \(errorResponse)")
                }
                print("ERROR IN AUDIO CALL, status code: \(httpResponse.statusCode)")
            }
        } else {
            print("Invalid response")
        }

         do {
             try data.write(to: conversationPath.appendingPathComponent("number\(fileNumber).mp3"))
             print("Audio file saved to: \(conversationPath.appendingPathComponent("number\(fileNumber).mp3").path)")
             audioFileNumber += 1
         } catch {
             print("Error saving audio file: \(error)")
         }
                
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
}

struct AudioRequest: Codable {
    let model : String
    let input : String
    let voice : String
}

struct CompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
}


//declare the colour palette
extension Color {
    static let imperialRed = Color(red: 244/255, green: 67/255, blue: 78/255)
    static let atomicTangerine = Color(red: 68/255, green: 95/255, blue: 147/255)
    static let backgroundOrange = Color(red: 97/255, green: 113/255, blue: 158/255)
}


// Dialogue structure
struct Dialogue: Hashable {
    let content: String
    let person1: Bool
}


// The object storing the information for a generated conversation. This object will be saved
class Conversation: ObservableObject{
    public var history:[String]=[]
    public var id:Int = 0
    public var position:TimeInterval = 0
    public var title:String = "The Fall of Rome"
    public var prompt:String=""
    public var person:String = ""
    public var description:String = ""
    public var length:TimeInterval = 2
    
    init(person:String,description:String,length:Double){
        self.person = person; self.description = description ; self.length = length * 60
        self.prompt = """
                Generate a podcast monologue on the topic of \(description). This is the first segment of a multi-part response series, so do not round off your ending and leave space for continuation in future prompts. The length of this segment should be approximately \(self.length/85) % of the total response. Ensure the content is factual, engaging, and informative. Avoid any prefaces or introductions, and do not include any extraneous text. You may use humor and explore related tangents as long as they remain relevant.
                """
//        initialise all variables
//        send data to DB?
    }
    init(id:Int){
//        all values then come from the DB
    }
}


struct Listen: View {
    @State var isLoading: Bool = true
    @Binding var currentView: NavigationState
    @Binding var previousView: NavigationState
    @Binding var conversation: Conversation
    @State var finalConversation : String = ""
    @State var currentMessage: Int = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var path: URL = URL(string: "https://example.com")!
    @State private var totalTime: TimeInterval = 0.0
    @State private var currentFileDownloading: Int = 0
    @State private var currentFilePlaying: Int = 0

    let chatGPT = ChatGPTAPI(apiKey: ProcessInfo.processInfo.environment["HIDDEN_GPTAPIKEY"] ?? "default-api-key")

    @Environment(\.colorScheme) var colorScheme
    
    private func setupAudio(FileNumber: Int) {
        path = chatGPT.conversationPath.appendingPathComponent("number\(FileNumber).mp3")
        print("Attempting to load audio file at path: \(path.path)")
        
        if FileManager.default.fileExists(atPath: path.path) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: path)
                audioPlayer?.prepareToPlay()
                totalTime += audioPlayer?.duration ?? 0.0
                print("Audio file loaded successfully. Duration: \(audioPlayer?.duration ?? 0.0)")
            } catch {
                print("Error loading audio: \(error)")
            }
        } else {
            print("Audio file does not exist at path: \(path.path)")
        }
    }
    
    private func playAudio() async {
        guard let audioPlayer = audioPlayer else { return }
        audioPlayer.play()
        isPlaying = true
        await waitFor(seconds: audioPlayer.duration)
        isPlaying = false
    }
    
    private func waitFor(seconds: TimeInterval?) async {
        guard let seconds = seconds else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    func generateDialogue(chatGPT: ChatGPTAPI, conversation: Conversation) async {
        do {
            var seed = true
            var end = false
            while totalTime < conversation.length{
                if conversation.length - totalTime < 90{
                    end = true
                }
                let response = try await chatGPT.sendChatMessage(seed ? conversation.prompt : !end ? """
Continue the monologue on the topic of \(conversation.description). This is the \(currentFileDownloading) segment of the series, and it should be approximately \(conversation.length/85) % of the total monologue. Maintain a consistent pacing and ensure the content flows logically from the previous segments. Do not include any prefaces, introductions, or text other than the monologue itself.

""":"""
Complete the monologue on the topic of \(conversation.description). This is the final segment of the series. Conclude with a comprehensive and impactful ending. The response should not include any prefaces, introductions, or any text other than the monologue itself. Ensure the conclusion ties together the key points and leaves a lasting impression.

""",record:true)
                conversation.history.append(response)
                // Generate a sound file per message
                do {
                    try await chatGPT.sendAudioRequest(response, voice:conversation.person, fileNumber: currentFileDownloading)
                    try await setupAudio(FileNumber: currentFileDownloading)
                    currentFileDownloading += 1
                } catch {
                    // Handle audio request error
                    print("Failed to send audio request for dialogue: \(response), error: \(error)")
                }
                seed = false
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
//    func propagateDialogue(chatGPT: ChatGPTAPI, conversation: Conversation) async {
//        do{
//            let response = try await chatGPT.sendChatMessage("please continue the dialogue",record:true)
//            conversation.history.append(response)
//            signedDialogue = await processDialogue(history: [response])
//            print("Propagation response signed: \(response)")
//            for dialogue in signedDialogue {
//                do {
//                    try await chatGPT.sendAudioRequest(dialogue.content, voice: dialogue.person1 ? conversation.person1voice : conversation.person2voice)
//                } catch {
//                    // Handle audio request error
//                    print("Failed to send audio request for MORE dialogue: \(dialogue.content), error: \(error)")
//                }
//            }
//        }catch{
//            print("Propagation Error: \(error)")
//        }
//    }

//    func processDialogue(history: [String]) async -> [Dialogue] {
//        var tempSignedDialogue: [Dialogue] = []
//        for string in history {
//            let dialogue = string.split(separator: "\n")
//            for line in dialogue {
//                var trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
//                if trimmedLine.contains("{1}") {
//                    trimmedLine = trimmedLine.replacingOccurrences(of: "{1}", with: "")
//                    tempSignedDialogue.append(Dialogue(content: String(trimmedLine), person1: true))
//                } else if trimmedLine.contains("{2}"){
//                    trimmedLine = trimmedLine.replacingOccurrences(of: "{2}", with: "")
//                    tempSignedDialogue.append(Dialogue(content: String(trimmedLine), person1: false))
//                }else{
//                    print("UNSIGNED DIALOGUE  ENSURE MESSAGES START WITH A{1} OR {2}")
//                }
//            }
//        }
//        return tempSignedDialogue
//    }
//    
//    func getAppropriateVoices() async {
//        do {
//            let categoriseVoicePrompt = """
//            Please categorize the following two people's voices: \(conversation.person1) and \(conversation.person2), as one of the following voice categories. The categorization should match their voices as closely as possible, considering their gender and voice characteristics. The categories for \(conversation.person1) and \(conversation.person2) must be different. Here are the categories:
//
//            - Alloy: American female, clearly pronounced, deeper pitch
//            - Echo: American male, young adult, slightly nasal
//            - Fable: British male, nerdy voice, nasal, clear, high-pitched
//            - Onyx: American, older male, deepest voice, velvety, monotonous, rich
//            - Nova: Older American female, slightly nasal, highest-pitched voice, frail, thin, soft
//            - Shimmer: American female, slightly nasal
//
//            Categorize \(conversation.person1) and \(conversation.person2) using the above categories and return only the two categories separated by a comma (e.g., Fable, Shimmer).
//            """
//            let response = try await chatGPT.sendChatMessage(categoriseVoicePrompt,record:false)
//            let voices = response.split(separator: ",").map { String($0) }
//            conversation.person1voice = voices[0].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//            conversation.person2voice = voices[1].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//            print("Response: \(response)")
//        } catch {
//            print("Error: \(error)")
//        }
//    }
    
    private func startPlayback() async {
            // Display the current message
        while currentFilePlaying < currentFileDownloading{
            setupAudio(FileNumber: currentFilePlaying)
            await playAudio()
            currentFilePlaying += 1
        }

            
            
            
            
            
            
            
            // Generate more dialogue if needed
//            if totalTime < conversation.length {
//                await propagateDialogue(chatGPT: chatGPT, conversation: conversation)
//            }
            
            
            
            
            
            
            
            
            
            
            
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atomicTangerine.ignoresSafeArea().opacity(0.9)
                
                VStack {
                    if isLoading {
                        ProgressView("Loading conversation...")
                            .foregroundColor(.black)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.0, green: 0.0, blue: 0.0)))
                            .onAppear {
                                Task {
                                    await generateDialogue(chatGPT: chatGPT, conversation: conversation)
                                    finalConversation = conversation.history.joined(separator: "\n \n")
                                    isLoading = false
                                }
                            }
                    } else {
                        VStack {
                            HStack {
                                Button(action: { previousView = currentView; currentView = .home ; if let audioPlayer = audioPlayer {
                                    audioPlayer.stop()}}) {
                                    Label("Back", systemImage: "return")
                                }
                                .frame(width: 150, alignment: .leading)
                                Button(action: { previousView = currentView; currentView = .home ;  if let audioPlayer = audioPlayer {
                                    audioPlayer.stop()}}) {
                                    Label("Save", systemImage: "star")
                                }
                                .frame(width: 150, alignment: .trailing)
                            }
                            .padding()
                            .bold()
                            .frame(width: 400, height: 50)
                            .foregroundColor(.atomicTangerine)
                            .background(.black)
                            .opacity(0.9)
                            
                            ScrollView {
                                    HStack {
                                        Text(finalConversation)
                                            .foregroundColor(.black)
                                            .padding()
                                            .cornerRadius(8)
                                            .frame(maxWidth: 350, alignment: .leading)
                                            .padding(5)
                                    }
                                }
                            }.onAppear(){
                                Task{
                                    await startPlayback()
                                }
                        }
                    }
                }
            }
        }.navigationBarBackButtonHidden(true)
    }
}



struct Home: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var currentView: NavigationState
    @Binding var previousView: NavigationState
    @Binding var conversation: Conversation
    @Binding var history : [Conversation]
    
    @State private var person: String = ""
    @State private var personComplete: Bool = true
    @State private var selectedSection: Int? = nil
    let personOptions = ["alloy", "echo", "onyx", "fable", "nova"]
    
    @State private var description: String = ""
    @State private var descriptionComplete: Bool = true
    @State private var descriptionwrong: Int = 0 // Declare it here
    @State private var descriptionLimit: Int = 250
    
    @State private var validSubmission: Bool = false
    @State private var length: Double = 5
    
    @State private var response: String = ""
    
    @State private var showDropdown: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atomicTangerine.ignoresSafeArea().opacity(0.8)
                ScrollView{
                    VStack {
                        headerView
                        
                        Text("logos \(response)")
                            .font(.largeTitle)
                            .bold()
                            .padding(20)
                        HStack{
                            Text("Create New")
                                .padding(.top)
                                .frame(alignment:.leading)
                            Spacer()
                            if showDropdown {
                                Button(action: {
                                    showDropdown = false
                                    description = "" // Clear the description if desired
                                    descriptionComplete = true // Mark description as complete
                                    descriptionwrong = 0 // Reset the wrong description indicator
                                }) {
                                    Label("", systemImage: "arrowshape.up.fill")
                                        .foregroundColor(.imperialRed)
                                        .padding(.top)
                                }
                            }


                            
                        }.frame(width:300)
                        
                        descriptionView
                        if showDropdown{
                            personSelectionView
                            lengthSelectionView
                            generateButton
                        }
                        Text("Your History")
                            .padding(.top)
                            .frame(width:300,alignment:.leading)
                        historySection
                    }
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Spacer()
            Button(action: {
                previousView = currentView
                currentView = .settings
            }) {
                Label("", systemImage: "gearshape")
                    .frame(width: 100, height: 50)
                    .font(.system(size: 35))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .opacity(0.9)
                    .bold()
                    .padding(.trailing)
            }
        }
        .frame(width: 400)
        .foregroundColor(.black)
        .opacity(1.0)
    }

    
    private var descriptionView: some View {
        VStack {
            mainVStack
        }
    }
    
    private var mainVStack: some View {
        VStack {
            ZStack {
                if !showDropdown {
                    placeholderText
                }
                dynamicTextEditor
            }

            if showDropdown {
                characterCountText
            }
        }
        .frame(width: 300, height: showDropdown ? CGFloat(90 + (Int(CGFloat(description.count) / 26) * 20)) : 50)
        .background(colorScheme == .dark ? .black : .white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    (descriptionComplete && (description.count <= descriptionLimit)) ? (colorScheme == .dark ? .white : .black) : .red,
                    lineWidth: 2
                )
        )
    }


    private var characterCountText: some View {
        Text("\(description.count)/\(descriptionLimit)")
            .font(.subheadline)
            .frame(width: 300, height: 20, alignment: .bottomTrailing)
            .foregroundColor(description.count > descriptionLimit ? .red : (colorScheme == .dark ? .white : .black))
            .opacity(0.9)
            .padding(.trailing)
            .background(colorScheme == .dark ? .black : .white)
    }

    private var dynamicTextEditor: some View {
        let dynamicHeight: CGFloat = {
            let baseHeight: CGFloat = 50
            let lineHeight: CGFloat = 21
            let characterPerLine: CGFloat = 38
            let numberOfLines = CGFloat(description.count) / characterPerLine
            return baseHeight + CGFloat(Int(numberOfLines) * Int(lineHeight))
        }()
        
        return TextEditor(text: $description)
            .foregroundColor(.black)
            .accentColor(.imperialRed)
            .frame(width: 280, height: dynamicHeight, alignment: .topLeading)
            .offset(x:5,y: 10)
            .onTapGesture {
                withAnimation {
                    showDropdown = true
                }
            }
            .zIndex(0.0)
    }


    private var placeholderText: some View {
        Text("Enter a topic...")
            .frame(width: 300, height: 50, alignment: .topLeading)
            .background(colorScheme == .dark ? .black : .white)
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .offset(x: 15, y: 15)
            .opacity(1.0)
            .onTapGesture {
                withAnimation {
                    showDropdown = true
                }
            }
            .zIndex(1.0)
    }
    
    
    private var personSelectionView: some View {
        HStack {
            HStack {
                Text("Voice")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .opacity(0.7)
                    .bold()
            }
            HStack(spacing: 0) {
                ForEach(0..<personOptions.count, id: \.self) { index in
                    personOptionView(option: personOptions[index], index: index)
                }
            }
            .cornerRadius(8.0)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        personComplete ? (colorScheme == .dark ? Color.white : Color.black) : Color.red,
                        lineWidth: 2
                    )
            )
        }.padding(.top)
    }

    private func personOptionView(option: String, index: Int) -> some View {
        Text(option)
            .foregroundColor(selectedSection == index ? .white : .black)
            .frame(width: 50, height: 50)
            .background(selectedSection == index ? Color.imperialRed : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.black, lineWidth: 2)
            )
            .onTapGesture {
                selectedSection = index
                person = personOptions[index]
            }
    }
    
    private var lengthSelectionView: some View {
        HStack {
            HStack {
                Text("Length")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .opacity(0.7)
                    .bold()

            }
            Slider(value: $length, in: 1...10)
                .frame(width: 180, height: 50)
                .accentColor(.imperialRed)
            
            Text("\(length, specifier: "%.00f")min")
                .bold()
                .frame(width: 50, height: 50)
        }
    }
    
    private var generateButton: some View{
        Button(action: {
            conversation = Conversation(person: person, description: description, length: length)
            submitSeed(conversation: conversation)
        }) {
            Text("Generate")
                .font(.subheadline)
                .frame(width: 300, height:50)
                .bold()
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .shadow(color: .black, radius: 100.0)
                .background(colorScheme == .dark ? .black : .imperialRed)
                .opacity(0.9)
                .cornerRadius(5.0)
                .shadow(color: .black.opacity(0.7), radius: 5, x: 3, y: 3)
        }

        
    }

    
    private var historySection: some View {
        return
        ForEach(history.indices, id: \.self) { index in
            HStack {
                Text(history[index].title)
                    .padding(.leading)
                    .frame(width:200, alignment: .leading)
                    .bold()
                Spacer()
                Button(action: {
                    conversation = Conversation(id:history[index].id)
                    previousView = currentView
                    currentView = .listen
                }) {
                    Label("", systemImage: "play.fill")
                }
                Button(action: {
                    // Download action
                }) {
                    Label("", systemImage: "star.fill")
                }
                Button(action: {
                    // Share action
                }) {
                    Label("", systemImage: "ellipsis")
                }.padding(.trailing)
            }
            .foregroundColor(.white)
            .opacity(0.9)
            .frame(width:300,height:50)
            .background(.black)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 2)
            )
            .cornerRadius(5.0)
            .padding(5)
        }
    }
    
    // MARK: - Functions
    
    private func submitSeed(conversation: Conversation) {
        personComplete = !conversation.person.isEmpty
        descriptionComplete = !description.isEmpty && description.count <= descriptionLimit
        
        if descriptionComplete && personComplete && (description.count * person.count != 0) {
            validSubmission = true
            previousView = currentView
            currentView = .listen
        }
    }
}
    
    
    struct Saved:View{
        @Environment(\.colorScheme) var colorScheme
        @Binding var currentView : NavigationState
        @Binding var previousView : NavigationState
        var body: some View{
            NavigationStack{
                ZStack{
                    Color.atomicTangerine.ignoresSafeArea().opacity(0.8)
                    VStack{
                        HStack{
                            
                            Button(action: {
                                previousView = currentView
                                currentView = .home
                            }) {
                                Label("Home", systemImage: "house")
                                    .frame(width:100,height:50)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .opacity(0.9)
                                    .bold()
                                    .padding(.leading)
                            }
                            Spacer()
                        }
                        Text("Saved")
                    }
                }
            }
        }
    }
    
    struct Settings:View{
        @Environment(\.colorScheme) var colorScheme
        @Binding var currentView : NavigationState
        @Binding var previousView : NavigationState
        var body: some View{
            NavigationStack{
                ZStack{
                    Color.atomicTangerine.ignoresSafeArea().opacity(0.8)
                    VStack{
                        HStack{
                            
                            Button(action: {
                                previousView = currentView
                                currentView = .home
                            }) {
                                Label("Home", systemImage: "house")
                                    .frame(width:100,height:50)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .opacity(0.9)
                                    .bold()
                                    .padding(.leading)
                            }
                            Spacer()
                        }
                        Text("Settings")
                    }
                }
            }
        }
    }

struct PasswordReset: View {
    @Binding public var email : String
    @State private var realcode : String = String(Int.random(in: 100000...999999))
    @Binding var currentView : NavigationState
    @Binding var previousView : NavigationState
    @State private var code : String=""
    @State private var borderThickness : Int = 0
    @State private var codeSent:Bool=false
    @State private var remainingTime: Int = 100 // Total time in seconds
    @State private var timerIsActive: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {

                Color.atomicTangerine.ignoresSafeArea().opacity(0.8)
                Circle().scale(1.7).foregroundColor(.atomicTangerine.opacity(0.7))
                Circle().scale(1.2).foregroundColor(.black.opacity(0.05))
                VStack{
                    Button(action: { previousView = currentView; currentView = .login}) {
                        Label("Back", systemImage: "return")
                            .frame(width:300,alignment:.leading)
                            .foregroundColor(.black)
                    }
                    Text("Reset Password")
                        .font(.largeTitle)
                        .bold()
                        .padding()

                    if !codeSent{
                        Button(action: {
                            codeSent = true
                            timerIsActive = true
                            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                                if remainingTime > 0 {
                                    remainingTime -= 1
                                } else {
                                    timer.invalidate()
                                    timerIsActive = false
                                }
                            }
                            //            GENERATE CODE AND SEND TO EMAIL
//                            start countdown
                        }) {
                            VStack{
                                Label("", systemImage: "paperplane.circle.fill")
                                    .font(.system(size: 70))
                                    .frame(width:150,height:150,alignment:.center)
                                    .foregroundColor(.black)
                                    .opacity(0.9)
                                    .bold()
                                Text("Click to send verification code to:\n\(email)")
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    HStack{
                        if codeSent{
                            Button(action: {
                                if remainingTime == 0{
                                    timerIsActive = true
                                    remainingTime = 100
                                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                                        if remainingTime > 0 {
                                            remainingTime -= 1
                                        } else {
                                            timer.invalidate()
                                            timerIsActive = false
                                        }
                                    }
                                    //GENERATE CODE AND SEND TO EMAIL
                                    //restart countdown
                                }
                            }) {
                                if remainingTime > 0{
                                    Label("Resend in \(remainingTime)s", systemImage: "paperplane.fill")
                                        .frame(width:150,height:50,alignment:.leading)
                                        .foregroundColor(.black)
                                        .opacity(0.9)
                                        .bold()
                                }else{
                                    Label("Resend code", systemImage: "paperplane.fill")
                                        .frame(width:150,height:50,alignment:.leading)
                                        .foregroundColor(.black)
                                        .opacity(0.9)
                                        .bold()
                                }
                            }
                        }
                        Button(action: {
                            /// OPEN MAIL APP
                        }) {
                            Label("Open mail", systemImage: "envelope.fill")
                                .frame(width:150,height:50,alignment:(codeSent ? .trailing : .center))                                    .foregroundColor(.black)
                                .opacity(0.9)
                                .bold()
                        }
                    }
                    if codeSent{
                        Text("Enter code below")
                            .font(.subheadline)
                            .frame(width:300,height:30,alignment:.leading)
                        ZStack{
                            TextField("",text:$code)
                                .onTapGesture {
                                    borderThickness = 4
                                }
                                .onChange(of: code) { newValue in
                                    if code.count > 6 {
                                        code = String(code.prefix(6))
                                    }
                                }                                .foregroundColor(.backgroundOrange)
                                .accentColor(.backgroundOrange)
                                .opacity(1.0)
                                .frame(width:280,height:50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            .black,
                                            lineWidth:CGFloat(borderThickness)
                                        )
                                )
                            
                            HStack(spacing: 5) {
                                ForEach(0..<6, id: \.self) { index in
                                    TextField("", text: Binding(
                                        get: {
                                            // Safely get the character at the index or return an empty string
                                            if index < code.count {
                                                return String(code[code.index(code.startIndex, offsetBy: index)])
                                            }
                                            return ""
                                        },
                                        set: { newValue in
                                            // Update the specific character in the code
                                            if newValue.isEmpty || newValue.count > 1 || !newValue.allSatisfy({ $0.isWholeNumber }) {
                                                return
                                            }
                                            let startIndex = code.index(code.startIndex, offsetBy: index)
                                            if index < code.count {
                                                code.replaceSubrange(startIndex...startIndex, with: newValue)
                                            } else if index == code.count {
                                                code.append(newValue)
                                            }
                                        }
                                    ))
                                    .frame(width: 40, height: 50, alignment: .center)
                                    .font(.system(size: 24))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .multilineTextAlignment(.center)
                                    .disabled(true)
                                }
                            }
                        }
                    }
                    if code.count >= 6{
                        Button(action: {
//                            sendEmail(email:$email,code:$code)
                        }) {
                            Text("Submit")
                                .font(.subheadline)
                                .frame(width: 300, height:50)
                                .bold()
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .shadow(color: .black, radius: 100.0)
                                .background(colorScheme == .dark ? .black : .white)
                                .opacity(0.9)
                                .cornerRadius(5.0)
                                .shadow(color: .black.opacity(0.7), radius: 5, x: 3, y: 3)
                                .padding()
                        }
                    }
                }
            }
        }
    }
}

    struct Authentication: View {
        @Binding var email:String
        @State private var password: String = ""
        @State private var wrongEmail: Int = 0
        @State private var wrongPassword: Int = 0
        @Binding var loggedIn: Bool
        @Binding var currentView: NavigationState
        @Binding var previousView: NavigationState
        
        @State private var newPassword: String = ""
        @State private var newPasswordConfirmed: String = ""
        @State private var existingMember: Bool = false
        @State private var newMember: Bool = false
        
        @State private var emailError: ValidationError = .none
        @State private var passwordError:ValidationError = .none
        @State private var emailErrorMessage: String = ""
        @State private var passwordErrorMessage: String = ""
        
        enum ValidationError {
            case passwordMismatch
            case invalidEmail
            case weakPassword
            case none
        }
        
        @State private var errorState: ValidationError = .none
        @State private var errorMessage: String = ""
        
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            NavigationStack {
                ZStack {
                    Color.atomicTangerine.ignoresSafeArea().opacity(0.8)
                    Circle().scale(1.7).foregroundColor(.atomicTangerine.opacity(0.7))
                    Circle().scale(1.2).foregroundColor(.black.opacity(0.05))
                    VStack {
                        Text("logos")
                            .font(.largeTitle)
                            .bold()
                            .padding()
                        
                        if newMember{
                            Text("Unrecognised address. Register below:")
                                .font(.subheadline)
                                .frame(width: 300, alignment: .bottomLeading)
                        }
                        
                        TextField("email", text: $email)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .opacity(0.9)
                            .padding()
                            .background(colorScheme == .dark ? .black : .white).opacity(0.9)
                            .frame(width: 300, height: 50)
                            .accentColor(.atomicTangerine)
                            .textContentType(.emailAddress)
                            .border(.red, width: CGFloat(wrongEmail))
                            .cornerRadius(5.0)
                        
                        if emailError != .none{
                            Label(emailErrorMessage,systemImage:"multiply")
                                .frame(width:300,height:50,alignment:.leading)
                                .foregroundColor(.imperialRed)
                                .bold()
                        }
                        
                        if !(newMember || existingMember){
                            Button("Next") {
                                if checkEmailValidity(email: email) {
                                    checkUserExistence(email: email) { exists in
                                        DispatchQueue.main.async {
                                            if exists {
                                                existingMember = true  // This triggers the password field to show
                                            } else {
                                                newMember = true
//                                                previousView = .login
//                                                currentView = .register
                                            }
                                        }
                                    }
                                }
                            }

                            .font(.subheadline)
                            .bold()
                            .foregroundColor(colorScheme == .dark ? .black : .white).opacity(0.9)
                            .padding()
                            .shadow(color: .black, radius: 100.0)
                            .background(colorScheme == .dark ? .white : .black).opacity(0.9)
                            .cornerRadius(5.0)
                            .frame(width: 300, height: 75)
                            .shadow(color: .black.opacity(0.7), radius: 5, x: 3, y: 3)
                        }
                        
                        if existingMember {
                            SecureField("password", text: $password)
                                .foregroundColor(colorScheme == .dark ? .white : .black).opacity(0.9)
                                .padding()
                                .background(colorScheme == .dark ? .black : .white).opacity(0.9)
                                .frame(width: 300, height: 50)
                                .accentColor(.atomicTangerine)
                                .textContentType(.password)
                                .border(.red, width: CGFloat(wrongPassword))
                                .cornerRadius(5.0)
                            
                            Button("login") {
                                authenticateUser(email: email, password: password)
                            }
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(colorScheme == .dark ? .black : .white).opacity(0.9)
                            .padding()
                            .shadow(color: .black, radius: 100.0)
                            .background(colorScheme == .dark ? .white : .black).opacity(0.9)
                            .cornerRadius(5.0)
                            .frame(width: 300, height: 75)
                            .shadow(color: .black.opacity(0.7), radius: 5, x: 3, y: 3)
                            
                            Button("Forgot password? Click here") {
                                previousView = currentView
                                currentView = .passwordResest
                            }
                            .frame(width: 300, height: 50)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .opacity(0.6)
                            .font(.system(size: 15))
                        }
                        
                        if newMember {
                            SecureField("password", text: $newPassword)
                                .foregroundColor(colorScheme == .dark ? .white : .black).opacity(0.9)
                                .padding()
                                .background(colorScheme == .dark ? .black : .white).opacity(0.9)
                                .frame(width: 300, height: 50)
                                .accentColor(.atomicTangerine)
                                .textContentType(.password)
                                .border(.red, width: CGFloat(wrongPassword))
                                .cornerRadius(5.0)

                            SecureField("confirm password", text: $newPasswordConfirmed)
                                .foregroundColor(colorScheme == .dark ? .white : .black).opacity(0.9)
                                .padding()
                                .background(colorScheme == .dark ? .black : .white).opacity(0.9)
                                .frame(width: 300, height: 50)
                                .accentColor(.atomicTangerine)
                                .textContentType(.password)
                                .border(.red, width: CGFloat(wrongPassword))
                                .cornerRadius(5.0)
                            
                            if passwordError != .none{
                                Label(passwordErrorMessage,systemImage:"multiply")
                                    .frame(width:300,height:(passwordError == .passwordMismatch ? 50:100),alignment:.leading)
                                    .foregroundColor(.imperialRed)
                                    .bold()
                            }
                            
                            HStack{
                                Button(action: { newMember = false}) {
                                    Label("Back", systemImage: "return")
                                }
                                .foregroundColor(.imperialRed)
                                Spacer()
                                Button("Register") {
                                    createAccount(email: email, newPassword: newPassword, newPasswordConfirmed: newPasswordConfirmed)
                                }
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(colorScheme == .dark ? .black : .white).opacity(0.9)
                                .padding()
                                .shadow(color: .black, radius: 100.0)
                                .background(colorScheme == .dark ? .white : .black).opacity(0.9)
                                .cornerRadius(5.0)
                                .shadow(color: .black.opacity(0.7), radius: 5, x: 3, y: 3)
                            }.frame(width:300,height:75)
                            
                        }
                    }.padding()
                }
            }
        }

        func checkEmailValidity(email: String) -> Bool{
            var flag : Bool
            let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
            
            if !emailPredicate.evaluate(with: email) {
                emailError = .invalidEmail
                emailErrorMessage = "invalid email"
                wrongEmail = 4
                flag = false
            } else {
                emailError = .none
                emailErrorMessage = ""
                wrongEmail = 0
                flag = true
            }
            return flag
        }

        
        func checkNewPasswordValidity(password1:String,password2:String) -> Bool{
            var flag : Bool
            let passwordRegEx = "^(?=.*[a-z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$"
            let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegEx)
            if newPassword != newPasswordConfirmed {
                passwordError = .passwordMismatch
                passwordErrorMessage = "passwords dont match"
                flag = false
            } else if !passwordPredicate.evaluate(with: newPassword) {
                passwordError = .weakPassword
                passwordErrorMessage = "password must be 8+ characters including uppercase & lowercase characters,digits and one of @$!%*?&"
                flag = false
            } else {
                passwordError = .none
                passwordErrorMessage = ""
                flag = true
            }
            print("New password result: \(flag) password1 was \(password1) and password2 was \(password2)")
            return flag
        }
        
        
        // Function to validate email and password
       func createAccount(email: String, newPassword: String, newPasswordConfirmed: String){
           if checkEmailValidity(email: email) && checkNewPasswordValidity(password1: newPassword, password2: newPasswordConfirmed){
               addUserToDataBase(email: email, password: newPasswordConfirmed)
            }
        }
        
        func addUserToDataBase(email: String, password: String) {
            print("adding user to DB")
            let apiKey = ProcessInfo.processInfo.environment["HIDDEN_SPREADSHEETAPIKEY"] ?? "default-id"
            let spreadsheetId = ProcessInfo.processInfo.environment["HIDDEN_SPREADSHEETID"] ?? "default-id"

            // Step 1: Read the existing data to find the last row
            let range = "Sheet1!A:A" // Read only column A to find the last filled row
            let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/\(range)?key=\(apiKey)"
            
            guard let url = URL(string: urlString) else {
                fatalError("Invalid URL")
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print("Error:", error ?? "Unknown error")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let values = json["values"] as? [[String]] {
                        
                        // Step 2: Determine the last row
                        let lastRow = values.count + 1 // Next row to write
                        let newRange = "Sheet1!A\(lastRow):B\(lastRow)" // Adjust range for email and password
                        
                        // Step 3: Prepare to write email and password
                        let writeUrlString = "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/\(newRange)?valueInputOption=RAW&key=\(apiKey)"
                        
                        guard let writeUrl = URL(string: writeUrlString) else {
                            fatalError("Invalid write URL")
                        }

                        var writeRequest = URLRequest(url: writeUrl)
                        writeRequest.httpMethod = "PUT"

                        // Data to write
                        let body: [String: Any] = [
                            "range": newRange,
                            "majorDimension": "ROWS",
                            "values": [
                                [email, password]
                            ]
                        ]

                        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
                        writeRequest.httpBody = jsonData
                        writeRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

                        // Step 4: Send the request to write data
                        let writeTask = URLSession.shared.dataTask(with: writeRequest) { data, response, error in
                            guard let data = data, error == nil else {
                                print("Error:", error ?? "Unknown error")
                                return
                            }
                            
                            do {
                                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                                    print("Response:", json)
                                }
                            } catch {
                                print("JSON Error:", error.localizedDescription)
                            }
                        }
                        
                        writeTask.resume()
                    }
                } catch {
                    print("JSON Error:", error.localizedDescription)
                }
            }

            task.resume()
        }

        

        func authenticateUser(email: String, password: String){
            let apiKey = ProcessInfo.processInfo.environment["HIDDEN_SPREADSHEETAPIKEY"] ?? "default-id"
            let spreadsheetId = ProcessInfo.processInfo.environment["HIDDEN_SPREADSHEETID"] ?? "default-id"
            let range = "Sheet1!A2:B10" // Adjust the range as needed
            let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/\(range)?key=\(apiKey)"
            var flag = false
            
            guard let url = URL(string: urlString) else {
                fatalError("Invalid URL")
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print("Error:", error ?? "Unknown error")
                    return
                }

                // Print the raw response data for debugging
//                if let rawResponse = String(data: data, encoding: .utf8) {
//                    print("Raw Response: \(rawResponse)")
//                }

                do {
                    // Parse the JSON response
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let values = json["values"] as? [[String]] {
                       for row in values {
                            if row[1] == password.lowercased(){
                                print("the password matches")
                                flag = true
                                wrongEmail = 0
                                wrongPassword = 0
                                loggedIn = true
                                previousView = currentView
                                currentView = .home
                            }
                        }
                        if !flag{
                            wrongPassword = 4
                        }
                        
                    } else {
                        print("No data found or JSON parsing failed.")
                    }
                } catch {
                    print("JSON Error:", error.localizedDescription)
                }
            }
            task.resume()

        }
        
//        func checkUserExistence(email: String) {
//            // Assume we have a CSV file in the app's Documents directory
//            print("checking user existence")
//            let fileManager = FileManager.default
//            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
//                let csvFileURL = documentsDirectory.appendingPathComponent("db.csv")
//                
//                print("db address: \(csvFileURL)")
//
//                
//                if userExists(email: email, inCSVFile: csvFileURL) {
//                    existingMember = true
//                    print("user exists")
//                } else {
//                    newMember = true
//                    print("user doesnt exist")
//                }
//            } else {
//                print("Documents directory not found")
//            }
//        }
        
        func checkUserExistence(email: String, completion: @escaping (Bool) -> Void) {
            let apiKey = ProcessInfo.processInfo.environment["HIDDEN_SPREADSHEETAPIKEY"] ?? "default-id"
            let spreadsheetId = ProcessInfo.processInfo.environment["HIDDEN_SPREADSHEETID"] ?? "default-id"
            print("API Key: \(apiKey)")
            print("Spreadsheet ID: \(spreadsheetId)")
            let range = "Sheet1!A2:B10"
            let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/\(range)?key=\(apiKey)"

            guard let url = URL(string: urlString) else {
                fatalError("Invalid URL")
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print("Error:", error ?? "Unknown error")
                    completion(false)  // Ensure we call completion with failure
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let values = json["values"] as? [[String]] {
                        print("looking for: \(email)")
                        for row in values {
                            if row[0].lowercased() == email.lowercased() {
                                print("email exists in db")
                                completion(true)  // Pass success once found
                                return
                            }
                        }
                    } else {
                        print("No data found or JSON parsing failed.")
                    }
                } catch {
                    print("JSON Error:", error.localizedDescription)
                }
                completion(false)  // If no email was found, call completion with false
            }

            task.resume()
        }

        
        
//        func parseCSV(fileURL: URL) -> [[String: String]]? {
//            do {
//                print("parsing csv")
//                let content = try String(contentsOf: fileURL, encoding: .utf16)
//                let rows = content.split(separator: "\n").map { $0.split(separator: ",") }
//                
//                guard let header = rows.first?.map({ String($0) }) else {
//                    print("No headers found")
//                    return nil
//                }
//                
//                let data = rows.dropFirst().map { row in
//                    var dict = [String: String]()
//                    for (index, value) in row.enumerated() {
//                        if index < header.count {
//                            dict[header[index]] = String(value)
//                        }
//                    }
//                    return dict
//                }
//                
//                return data
//            } catch {
//                print("Error reading CSV file: \(error)")
//                return nil
//            }
//        }
        
//        func userExists(email: String, inCSVFile fileURL: URL) -> Bool {
//            guard let users = parseCSV(fileURL: fileURL) else {
//                print("Failed to parse CSV file")
//                return false
//            }
//            
//            for user in users {
//                print(user)
//                if user["email"] == email.lowercased() {
//                    return true
//                }
//            }
//            return true
//        }
//        
//        func userExists(email: String, password: String, inCSVFile fileURL: URL) -> Bool {
//            guard let users = parseCSV(fileURL: fileURL) else {
//                print("Failed to parse CSV file")
//                return false
//            }
//            
//            for user in users {
//                if user["email"] == email && user["password"] == password {
//                    return true
//                }
//            }
//            return false
//        }
    }

    
    enum NavigationState {
        case home
        case login
        case register
        case settings
        case saved
        case listen
        case passwordResest
        
    }
    
    struct ContentView:View{
        //    These are all the global variables that must be passed between views
        @State private var currentView : NavigationState = .login
        @State private var previousView : NavigationState = .login
        @State private var conversation : Conversation = Conversation(person: "", description: "democracy", length: 2.0)
        @State private var loggedIn: Bool = false
        @State private var email: String = ""
        @State private var history : [Conversation] = [Conversation(person: "", description: "democracy", length: 2.0),Conversation(person: "", description: "democracy", length: 2.0),Conversation(person: "", description: "democracy", length: 2.0)]
        
        var body: some View {
            ZStack {
                VStack{
                    if loggedIn{
                        switch currentView {
                        case .home:
                            Home(currentView:$currentView,previousView:$previousView, conversation:$conversation, history: $history)
                                .transition(transitionFor(previous: previousView, current: currentView))
                                .animation(.easeInOut(duration: 0.5))
                            
                        case .settings:
                            Settings(currentView:$currentView,previousView:$previousView)
                                .transition(transitionFor(previous: previousView, current: currentView))
                                .animation(.easeInOut(duration: 0.5))
                        case .saved:
                            Saved(currentView:$currentView,previousView:$previousView)
                                .transition(transitionFor(previous: previousView, current: currentView))
                                .animation(.easeInOut(duration: 0.5))
                            
                        case .listen:
                            Listen(currentView:$currentView,previousView:$previousView, conversation:$conversation)
                                .transition(transitionFor(previous: previousView, current: currentView))
                                .animation(.easeInOut(duration: 0.5))
                            
                        default:
                            Text("Unknown view") // Placeholder view
                        }
                    }else{
                        if currentView == .login{
                            Authentication(email:$email, loggedIn:$loggedIn,currentView:$currentView,previousView:$previousView)
                                .transition(.move(edge: .top))
                                .animation(.bouncy(duration: 0.5))
                            
                        }else if currentView == .passwordResest{
                            PasswordReset(email:$email,currentView:$currentView,previousView:$previousView)
                        }
                    }
                }
            }
            .background(Color.backgroundOrange.ignoresSafeArea())
        }
    }
    
    private func transitionFor(previous: NavigationState,current: NavigationState) -> AnyTransition {
        switch (previous, current) {
        case (.login, .home):
            return .move(edge: .top)
        case (.login, .register):
            return .move(edge: .bottom)
        case (.register, .login):
            return .move(edge: .top)
        case (.home, .saved),(.home, .settings):
            return .move(edge: .trailing)
        case (.saved, .home),(.settings, .home),(.listen, .home):
            return .move(edge: .leading)
        case (.saved, .listen),(.home, .listen):
            return .move(edge: .trailing)
        case (.listen, .saved), (.listen , .home):
            return .move(edge: .leading)
        case (.login,.passwordResest):
            return .move(edge: .bottom)

        default:
            return .identity
        }
    }
    
    #Preview {
        ContentView()
        //    Home()
        //    Login()
//        Create(currentView: .create, previousView: .home, conversation: Conversation(person: "String", description: "String", length: 0.0))
        //    Create(currentView:.create,conversation: Conversation(person1: "socrates", person2: "aristotle", description: "democracy", length: 0.0))
        //    Listen(conversation: Conversation(person1: "socrates", person2: "aristotle", description: "democracy", length: 0.0))
    }

