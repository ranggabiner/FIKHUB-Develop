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
    
    @StateObject private var profileViewModel: ProfileViewModel
    
    init() {
        do {
            container = try ModelContainer(for: UserStorage.self)
            let context = ModelContext(container)
            repository = SwiftDataUserRepository(context: context)
            saveUserProfileUseCase = SaveUserProfileUseCaseImpl(repository: repository)
            getLatestUserProfileUseCase = GetLatestUserProfileUseCaseImpl(repository: repository)
            
            let viewModel = ProfileViewModel(
                saveUserProfileUseCase: saveUserProfileUseCase,
                getLatestUserProfileUseCase: getLatestUserProfileUseCase
            )
            _profileViewModel = StateObject(wrappedValue: viewModel)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if profileViewModel.isOnboardingCompleted {
                InitScheduleView()
            } else {
                ProfileFormView(viewModel: profileViewModel)
            }
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

//models
struct UserModel: Identifiable {
    var id: UUID
    var onboarding: OnboardingModel
}

struct OnboardingModel: Codable {
    var name: String = ""
    var prodi: String = ""
    var semester: String = ""
}

struct ScheduleModel: Codable {
    var subjectName: String = ""
    var roomLocation: String = ""
    var day: String = ""
    var startTime: Date = Date()
    var endTime: Date = Date()
}

struct IdentifiableError: Identifiable {
    let id = UUID()
    let error: Error
}

//components
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

struct ScheduleList: View {
    @State private var items = [
        ListItem(title: "Pemrograman Web", room: "FIK-201", startTime: "08:00", endTime: "09:00")
    ]

    var body: some View {
        List {
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.room)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(item.startTime)
                            .font(.subheadline)
                        Text(item.endTime)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        print("tap delete")
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        print("tap edit")
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct ListItem: Identifiable {
    let id = UUID()
    var title: String
    var room: String
    var startTime: String
    var endTime: String
}

// viewmodels
class ProfileViewModel: ObservableObject {
    private let saveUserProfileUseCase: SaveUserProfileUseCase
    @Published var error: IdentifiableError?
    private let getLatestUserProfileUseCase: GetLatestUserProfileUseCase
    @Published var savedUser: UserModel?
    @Published var shouldNavigateToSchedule: Bool = false

    
    @Published var name: String = ""
    @Published var selectedProgram: String = "Pilih Program Studi"
    @Published var selectedSemester: String = "Pilih Semester"
    @Published var isSaving: Bool = false
    @Published var isOnboardingCompleted: Bool {
        didSet {
            UserDefaults.standard.set(isOnboardingCompleted, forKey: "isOnboardingCompleted")
        }
    }
    
    init(saveUserProfileUseCase: SaveUserProfileUseCase, getLatestUserProfileUseCase: GetLatestUserProfileUseCase) {
        self.saveUserProfileUseCase = saveUserProfileUseCase
        self.getLatestUserProfileUseCase = getLatestUserProfileUseCase
        self.isOnboardingCompleted = UserDefaults.standard.bool(forKey: "isOnboardingCompleted")
    }

    func saveProfile() {
        isSaving = true
        do {
            try saveUserProfileUseCase.execute(name: name, prodi: selectedProgram, semester: selectedSemester)
            isSaving = false
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
    
    func saveProfileAndNavigate() {
        saveProfile()
        isOnboardingCompleted = true
        shouldNavigateToSchedule = true
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
                        viewModel.saveProfileAndNavigate()
                    })
                    .disabled(viewModel.isSaving)
                    .padding(.horizontal)
                }
            }
            .navigationBarTitle("Profile", displayMode: .large)
            .navigationDestination(isPresented: $viewModel.shouldNavigateToSchedule) {
                InitScheduleView()
                    .navigationBarBackButtonHidden(true)
            }
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
    @Binding var selectedSemester: String
    @Environment(\.presentationMode) var presentationMode


    var body: some View {
        Form {
            ForEach(Array(semesters.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                Button(action: {
                    selectedSemester = value
                    presentationMode.wrappedValue.dismiss()
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

struct InitScheduleView: View {
    @State private var isAddScheduleViewPresented = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    Spacer()
                    Text("Untuk menambahkan jadwal kelas Anda, silakan klik tombol tambah (+) yang terletak di sudut kanan bawah.")
                        .font(.callout)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            isAddScheduleViewPresented = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title.weight(.semibold))
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Jadwal")
                            .font(.headline)
                        Spacer()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Selesai") {
                        print("tap selesai")
                    }
                }
            }
            .navigationBarTitle("Jadwal", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $isAddScheduleViewPresented) {
            AddScheduleView()
        }
    }
}

struct AddScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var selectedDay = 0
    
    let daysOfWeek = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: SubjectPickerView()) {
                        Text("Mata Kuliah")
                            .foregroundStyle(.orange)
                    }
                    NavigationLink(destination: RoomLocationView()) {
                        Text("Lokasi")
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    Picker("Hari", selection: $selectedDay) {
                        ForEach(0..<daysOfWeek.count, id: \.self) { index in
                            Text(daysOfWeek[index]).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    DatePicker(
                        "Mulai",
                        selection: $date,
                        displayedComponents: [.hourAndMinute]
                    )
                    DatePicker(
                        "Selesai",
                        selection: $date,
                        displayedComponents: [.hourAndMinute]
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tambah") {
                        print("tambah tapped")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Baru")
                        .font(.headline)
                }
            }
        }
    }
}

struct SubjectPickerView: View {
    let subjects: [Int:String] = [
        1: "Analisis Bisnis",
        2: "Interaksi Manusia Dan Komputer",
        3: "Manajemen Proyek Sistem Informasi",
        4: "Pemrograman Web",
        5: "Pengantar Data Science",
        6: "Pengantar Teknologi Informasi",
        7: "Praktikum Interaksi Manusia Dan Komputer",
        8: "Praktikum Pemrograman Web",
        9: "Praktikum Sistem Operasi",
        10: "Sistem Informasi Manajemen",
        11: "Sistem Operasi",
        12: "Statistik dan Probabilitas",
        13: "Technopreneurship",
    ]
    @State private var searchText = ""

    var filteredSubjects: [(key: Int, value: String)] {
        if searchText.isEmpty {
            return Array(subjects.sorted(by: { $0.key < $1.key }))
        } else {
            return subjects.filter { $0.value.lowercased().contains(searchText.lowercased()) }
                .sorted(by: { $0.key < $1.key })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSubjects, id: \.key) { key, value in
                    Button(action: {
                        print("tap \(value)")
                    }) {
                        Text(value)
                            .foregroundColor(.black)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Cari")
            .navigationBarTitle("Mata Kuliah", displayMode: .large)

        }
    }
}

struct RoomLocationView: View {
    let subjects: [Int:String] = [
        1: "FIK-201",
        2: "FIKLAB-201",
        3: "FIKLAB-202",
        4: "FIKLAB-203",
        5: "FIKLAB-301",
        6: "FIKLAB-302",
        7: "FIKLAB-303",
        8: "FIKLAB-401",
        9: "FIKLAB-402",
        10: "FIKLAB-403",
    ]
    @State private var searchText = ""

    var filteredSubjects: [(key: Int, value: String)] {
        if searchText.isEmpty {
            return Array(subjects.sorted(by: { $0.key < $1.key }))
        } else {
            return subjects.filter { $0.value.lowercased().contains(searchText.lowercased()) }
                .sorted(by: { $0.key < $1.key })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSubjects, id: \.key) { key, value in
                    Button(action: {
                        print("tap \(value)")
                    }) {
                        Text(value)
                            .foregroundColor(.black)
                    }
                }
            }
            .navigationBarTitle("Jadwal", displayMode: .large)
            .searchable(text: $searchText, prompt: "Cari")
        }
    }
}
