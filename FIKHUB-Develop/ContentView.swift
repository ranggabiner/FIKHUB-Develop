//
//  ContentView.swift
//  FIKHUB-Develop
//
//  Created by Rangga Biner on 31/08/24.
//

import Foundation
import SwiftData
import SwiftUI

@main
struct FIKHUB_DevelopApp: App {
    let container: ModelContainer
    let repository: UserRepository
    let saveUserProfileUseCase: SaveUserProfileUseCase
    let getLatestUserProfileUseCase: GetLatestUserProfileUseCase

    init() {
        do {
            container = try ModelContainer(for: UserStorage.self)
            let context = ModelContext(container)
            repository = SwiftDataUserRepository(context: context)
            saveUserProfileUseCase = SaveUserProfileUseCaseImpl(repository: repository)
            getLatestUserProfileUseCase = GetLatestUserProfileUseCaseImpl(repository: repository)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            let viewModel = ProfileViewModel(
                saveUserProfileUseCase: saveUserProfileUseCase,
                getLatestUserProfileUseCase: getLatestUserProfileUseCase
            )
            ProfileFormView(viewModel: viewModel)
        }
    }
}

//manager
public class SwiftDataManager {
    public static var shared = SwiftDataManager()
    var container: ModelContainer?
    var context: ModelContext?

    init() {
        do {
            container = try ModelContainer(for: UserStorage.self)
            if let container {
                context = ModelContext(container)
            }
        } catch {
            debugPrint("Error initializing database container:", error)
        }
    }
}

//storage
@Model
class UserStorage {
    var id: UUID
    var onboarding: OnboardingModel
    
    init(id: UUID, onboarding: OnboardingModel) {
        self.id = id
        self.onboarding = onboarding
    }
    
    func toDomain() -> UserModel{
        return .init(
            id: self.id,
            onboarding: self.onboarding
        )
    }
}


// repository
protocol UserRepository {
    func saveUser(_ user: UserModel) throws
    func getUser(by id: UUID) throws -> UserModel?
    func getLatestUser() throws -> UserModel?

}

class SwiftDataUserRepository: UserRepository {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func saveUser(_ user: UserModel) throws {
        let userStorage = UserStorage(id: user.id, onboarding: user.onboarding)
        context.insert(userStorage)
        try context.save()
    }
    
    func getUser(by id: UUID) throws -> UserModel? {
        let descriptor = FetchDescriptor<UserStorage>(predicate: #Predicate { $0.id == id })
        let result = try context.fetch(descriptor)
        return result.first?.toDomain()
    }
    
    func getLatestUser() throws -> UserModel? {
        var descriptor = FetchDescriptor<UserStorage>(sortBy: [SortDescriptor(\.id, order: .reverse)])
        descriptor.fetchLimit = 1
        let result = try context.fetch(descriptor)
        return result.first?.toDomain()
    }

}

//usecase
protocol SaveUserProfileUseCase {
    func execute(name: String, prodi: String, semester: String) throws
}

class SaveUserProfileUseCaseImpl: SaveUserProfileUseCase {
    private let repository: UserRepository
    
    init(repository: UserRepository) {
        self.repository = repository
    }
    
    func execute(name: String, prodi: String, semester: String) throws {
        let onboarding = OnboardingModel(name: name, prodi: prodi, semester: semester)
        let user = UserModel(id: UUID(), onboarding: onboarding)
        try repository.saveUser(user)
    }
}

protocol GetLatestUserProfileUseCase {
    func execute() throws -> UserModel?
}

class GetLatestUserProfileUseCaseImpl: GetLatestUserProfileUseCase {
    private let repository: UserRepository
    
    init(repository: UserRepository) {
        self.repository = repository
    }
    
    func execute() throws -> UserModel? {
        return try repository.getLatestUser()
    }
}

//model
struct UserModel: Identifiable {
    var id: UUID
    var onboarding: OnboardingModel
}

struct OnboardingModel: Codable {
    var name: String = ""
    var prodi: String = ""
    var semester: String = ""
}

struct IdentifiableError: Identifiable {
    let id = UUID()
    let error: Error
}

//component
struct TextFieldClear: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let onClear: (() -> Void)?
    
    var body: some View {
        VStack {
            HStack {
                TextField(placeholder, text: $text)
                    .textFieldStyle(DefaultTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(keyboardType)
                
                if !text.isEmpty && onClear != nil {
                    Button(action: {
                        onClear?()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .font(.body)
        }

        
    }
}

struct ButtonFill: View {
    let title: String
    let action: () -> Void
    let backgroundColor: Color
    let foregroundColor: Color
    let height: CGFloat
    let cornerRadius: CGFloat
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    
    init(
        title: String,
        action: @escaping () -> Void,
        backgroundColor: Color = .orange,
        foregroundColor: Color = .white,
        height: CGFloat = 50,
        cornerRadius: CGFloat = 12,
        fontSize: CGFloat = 17,
        fontWeight: Font.Weight = .regular
    ) {
        self.title = title
        self.action = action
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.height = height
        self.cornerRadius = cornerRadius
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, maxHeight: height)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .foregroundColor(foregroundColor)
                .font(.system(size: fontSize, weight: fontWeight))
        }
    }
}

// viewmodel
class ProfileViewModel: ObservableObject {
    private let saveUserProfileUseCase: SaveUserProfileUseCase
    @Published var error: IdentifiableError?
    private let getLatestUserProfileUseCase: GetLatestUserProfileUseCase
    @Published var savedUser: UserModel?

    
    @Published var name: String = ""
    @Published var selectedProgram: String = "Pilih Program Studi"
    @Published var selectedSemester: String = "Pilih Semester"
    @Published var isSaving: Bool = false
    
    init(saveUserProfileUseCase: SaveUserProfileUseCase, getLatestUserProfileUseCase: GetLatestUserProfileUseCase) {
        self.saveUserProfileUseCase = saveUserProfileUseCase
        self.getLatestUserProfileUseCase = getLatestUserProfileUseCase
    }

    func saveProfile() {
        isSaving = true
        do {
            try saveUserProfileUseCase.execute(name: name, prodi: selectedProgram, semester: selectedSemester)
            isSaving = false
            // Handle successful save (e.g., navigate to next screen)
        } catch {
            self.error = IdentifiableError(error: error)
            isSaving = false
        }
    }
    
    func loadLatestUser() {
        do {
            savedUser = try getLatestUserProfileUseCase.execute()
        } catch {
            self.error = IdentifiableError(error: error)
        }
    }


}

//views
struct ProfileFormView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var showingSavedData = false

    
    init(viewModel: ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section {
                        HStack {
                            Text("Nama")
                                .frame(maxWidth: 100, alignment: .leading)
                            TextFieldClear(placeholder: "Nama Anda", text: $viewModel.name, keyboardType: .default, onClear: {
                                viewModel.name = ""
                            })
                        }
                    }
                    Section {
                        NavigationLink(destination: ProgramsView(selectedProgram: $viewModel.selectedProgram)) {
                            Text(viewModel.selectedProgram)
                                .foregroundStyle(.orange)
                        }
                        
                        NavigationLink(destination: SemesterView(selectedSemester: $viewModel.selectedSemester)) {
                            Text(viewModel.selectedSemester)
                                .foregroundStyle(.orange)
                        }
                    }
                    Section {
                        Button("Lihat Data Tersimpan") {
                            viewModel.loadLatestUser()
                            showingSavedData = true
                        }
                    }
                }
                VStack {
                    Spacer()
                    ButtonFill(title: "Lanjutkan", action: {
                        viewModel.saveProfile()
                    })
                    .disabled(viewModel.isSaving)
                    .padding(.horizontal)
                }
            }
            .navigationBarTitle("Profile", displayMode: .large)
            .alert(item: $viewModel.error) { identifiableError in
                Alert(
                    title: Text("Error"),
                    message: Text(identifiableError.error.localizedDescription)
                )
            }
            .sheet(isPresented: $showingSavedData) {
                if let user = viewModel.savedUser {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data Tersimpan:")
                            .font(.headline)
                        Text("Nama: \(user.onboarding.name)")
                        Text("Program Studi: \(user.onboarding.prodi)")
                        Text("Semester: \(user.onboarding.semester)")
                    }
                    .padding()
                } else {
                    Text("Tidak ada data tersimpan")
                }
            }
        }
    }
}

struct SemesterView: View {
    let semesters: [Int:String] = [
        1: "Semester 1",
        2: "Semester 2",
        3: "Semester 3",
        4: "Semester 4",
        5: "Semester 5",
        6: "Semester 6",
        7: "Semester 7",
        8: "Semester 8",
    ]
    @Binding var selectedSemester: String // Tambahkan ini
    @Environment(\.presentationMode) var presentationMode


    var body: some View {
        Form {
            ForEach(Array(semesters.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                Button(action: {
                    selectedSemester = value // Ubah ini
                    presentationMode.wrappedValue.dismiss() // Tambahkan ini untuk kembali ke view sebelumnya
                }) {
                    Text(value)
                        .foregroundColor(.black)
                }
            }
        }
        .navigationBarTitle("Pilih Semester", displayMode: .inline)
    }
}

struct ProgramsView: View {
    let programs: [Int:String] = [
        1: "D3 Sistem Informasi",
        2: "S1 Sistem Informasi",
        3: "S1 Informatika",
    ]
    @Binding var selectedProgram: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Form {
            ForEach(Array(programs.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                Button(action: {
                    selectedProgram = value
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(value)
                        .foregroundColor(.black)
                }
            }
        }
        .navigationBarTitle("Pilih Program Studi", displayMode: .inline)
    }
}


