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
            ContentView(profileViewModel: profileViewModel)
        }
    }
}

struct ContentView: View {
    @ObservedObject var profileViewModel: ProfileViewModel

    var body: some View {
        Group {
            if !profileViewModel.isOnboardingCompleted {
                ProfileFormView(viewModel: profileViewModel)
            } else if !profileViewModel.isInitScheduleCompleted {
                InitScheduleView(viewModel: profileViewModel)
            } else {
                ScheduleView()
            }
        }
        .onAppear {
            profileViewModel.loadLatestUser()
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
    var subjects: [String] // Tambahkan ini

    init(id: UUID, onboarding: OnboardingModel, subjects: [String] = []) {
        self.id = id
        self.onboarding = onboarding
        self.subjects = subjects
    }

    func toDomain() -> UserModel {
        return .init(
            id: self.id,
            onboarding: self.onboarding,
            subjects: self.subjects // Tambahkan ini
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
        let userStorage = UserStorage(id: user.id, onboarding: user.onboarding, subjects: user.subjects)
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
    func execute(name: String, prodi: String, semester: String, subjects: [String]) throws
}

class SaveUserProfileUseCaseImpl: SaveUserProfileUseCase {
    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func execute(name: String, prodi: String, semester: String, subjects: [String]) throws {
        let onboarding = OnboardingModel(name: name, prodi: prodi, semester: semester)
        let user = UserModel(id: UUID(), onboarding: onboarding, subjects: subjects)
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
    var subjects: [String]

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

struct ScheduleItem: Identifiable, Codable {
    let id: UUID
    var subject: String
    var location: String
    var day: String
    var startTime: Date
    var endTime: Date
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
    @Published var shouldNavigateToHome: Bool = false
    @Published var schedules: [ScheduleItem] = []


    
    @Published var name: String = ""
    @Published var selectedSemester: String = "Pilih Semester"
    @Published var isSaving: Bool = false
    @Published var isOnboardingCompleted: Bool {
        didSet {
            UserDefaults.standard.set(isOnboardingCompleted, forKey: "isOnboardingCompleted")
        }
    }
    @Published var isInitScheduleCompleted: Bool {
        didSet {
            UserDefaults.standard.set(isInitScheduleCompleted, forKey: "isInitScheduleCompleted")
        }
    }
    @Published var subjects: [String] = []
    let dayOrder = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]

    var sortedSchedules: [ScheduleItem] {
        schedules.sorted { (item1, item2) -> Bool in
            if let index1 = dayOrder.firstIndex(of: item1.day),
               let index2 = dayOrder.firstIndex(of: item2.day) {
                if index1 == index2 {
                    // Jika hari sama, urutkan berdasarkan waktu mulai
                    return item1.startTime < item2.startTime
                }
                // Jika hari berbeda, urutkan berdasarkan urutan hari
                return index1 < index2
            }
            return false
        }
    }

    
    private let subjectsByProdi: [String: [String]] = [
        "D3 Sistem Informasi": ["Basis Data", "Pemrograman Web", "Sistem Operasi"],
        "S1 Sistem Informasi": ["Analisis Sistem Informasi", "Manajemen Proyek TI", "Business Intelligence"],
        "S1 Informatika": ["Algoritma dan Struktur Data", "Kecerdasan Buatan", "Jaringan Komputer"]
    ]
    
    func updateSubjects() {
        subjects = subjectsByProdi[selectedProgram] ?? []
    }
    
    @Published var selectedProgram: String = "Pilih Program Studi" {
        didSet {
            updateSubjects()
        }
    }
    
    
    
    init(saveUserProfileUseCase: SaveUserProfileUseCase, getLatestUserProfileUseCase: GetLatestUserProfileUseCase) {
        self.saveUserProfileUseCase = saveUserProfileUseCase
        self.getLatestUserProfileUseCase = getLatestUserProfileUseCase
        self.isOnboardingCompleted = UserDefaults.standard.bool(forKey: "isOnboardingCompleted")
        self.isInitScheduleCompleted = UserDefaults.standard.bool(forKey: "isInitScheduleCompleted")
    }

    func saveProfile() {
        isSaving = true
        do {
            try saveUserProfileUseCase.execute(
                name: name,
                prodi: selectedProgram,
                semester: selectedSemester,
                subjects: subjects // Tambahkan ini
            )
            isSaving = false
        } catch {
            self.error = IdentifiableError(error: error)
            isSaving = false
        }
    }

    func loadLatestUser() {
        do {
            savedUser = try getLatestUserProfileUseCase.execute()
            if let user = savedUser {
                subjects = user.subjects // Muat daftar mata kuliah
            }
        } catch {
            self.error = IdentifiableError(error: error)
        }
    }

    func saveProfileAndNavigate() {
        saveProfile()
        isOnboardingCompleted = true
        shouldNavigateToSchedule = true
    }
    
    func ScheduleNavigate() {
        isInitScheduleCompleted = true
        shouldNavigateToHome = true
    }

    func saveSchedule(_ schedule: ScheduleItem) {
        schedules.append(schedule)
        saveSchedulesToStorage()
    }

    private func saveSchedulesToStorage() {
        if let encoded = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(encoded, forKey: "savedSchedules")
        }
    }

    func loadSchedulesFromStorage() {
        if let savedSchedules = UserDefaults.standard.data(forKey: "savedSchedules"),
           let decodedSchedules = try? JSONDecoder().decode([ScheduleItem].self, from: savedSchedules) {
            schedules = decodedSchedules
        }
    }

    func deleteSchedule(_ schedule: ScheduleItem) {
        schedules.removeAll { $0.id == schedule.id }
        saveSchedulesToStorage()
    }

    func updateSchedule(_ updatedSchedule: ScheduleItem) {
        if let index = schedules.firstIndex(where: { $0.id == updatedSchedule.id }) {
            schedules[index] = updatedSchedule
            saveSchedulesToStorage()
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
                        viewModel.saveProfileAndNavigate()
                    })
                    .disabled(viewModel.isSaving)
                    .padding(.horizontal)
                }
            }
            .navigationBarTitle("Profile", displayMode: .large)
            .navigationDestination(isPresented: $viewModel.shouldNavigateToSchedule) {
                InitScheduleView(viewModel: viewModel)
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
    @ObservedObject var viewModel: ProfileViewModel
    @State private var isAddScheduleViewPresented = false
    @State private var editingSchedule: ScheduleItem?


    var daysWithSchedules: [String] {
        return viewModel.dayOrder.filter { day in
            viewModel.sortedSchedules.contains { $0.day == day }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.schedules.isEmpty {
                    VStack {
                        Spacer()
                        Text("Untuk menambahkan jadwal kelas Anda, silakan klik tombol tambah (+) yang terletak di sudut kanan atas.")
                            .font(.callout)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(daysWithSchedules, id: \.self) { day in
                            Section(header: Text(day).textCase(.uppercase).foregroundStyle(.orange)) {
                                ForEach(viewModel.sortedSchedules.filter { $0.day == day }) { schedule in
                                    ScheduleItemView(schedule: schedule,
                                        onDelete: {
                                            viewModel.deleteSchedule(schedule)
                                        },
                                        onEdit: {
                                            editingSchedule = schedule
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading:
                Text("Jadwal")
                    .font(.headline)
                    .foregroundColor(.primary)
            )
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            isAddScheduleViewPresented = true
                        }, label: {
                            Image(systemName: "plus")
                                .font(.subheadline)
                        })
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.ScheduleNavigate()
                        }, label: {
                            Text("Selesai")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        })
                    }
                }
            }
            .sheet(isPresented: $isAddScheduleViewPresented) {
                AddScheduleView(viewModel: viewModel)
            }
            .sheet(item: $editingSchedule) { schedule in
                EditScheduleView(viewModel: viewModel, schedule: schedule)
            }
            .onAppear {
                viewModel.loadSchedulesFromStorage()
            }
            .navigationDestination(isPresented: $viewModel.shouldNavigateToHome) {
                ScheduleView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

struct ScheduleItemView: View {
    let schedule: ScheduleItem
    let onDelete: () -> Void
    let onEdit: () -> Void

    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(schedule.subject)
                    .font(.headline)
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                    Text(schedule.location)
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(formatTime(schedule.startTime))
                    .font(.subheadline)
                Text(formatTime(schedule.endTime))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Hapus", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }

    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AddScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @State private var selectedSubject: String = ""
    @State private var selectedLocation: String = ""
    @State private var selectedDay = 0
    @State private var startTime = Date()
    @State private var endTime = Date()


    
    let daysOfWeek = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: SubjectPickerView(viewModel: viewModel, selectedSubject: $selectedSubject)) {
                              Text(selectedSubject.isEmpty ? "Pilih Mata Kuliah" : selectedSubject)
                                  .foregroundStyle(.orange)
                          }
                    NavigationLink(destination: RoomLocationView(selectedLocation: $selectedLocation)) {
                        Text(selectedLocation.isEmpty ? "Pilih Lokasi" : selectedLocation)
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    Picker("Hari", selection: $selectedDay) {
                        ForEach(0..<daysOfWeek.count, id: \.self) { index in
                            Text(daysOfWeek[index]).tag(index)
                        }
                    }
                }
                Section {
                    DatePicker("Jam Mulai", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Jam Selesai", selection: $endTime, displayedComponents: .hourAndMinute)
                }
            }
            .navigationBarTitle("Tambah", displayMode: .inline)
            .navigationBarItems(trailing: Button("Simpan") {
                saveSchedule()
            })
            .navigationBarItems(leading: Button("Batal") {
                dismiss()
            })
        }
        
    }
    private func saveSchedule() {
        let newSchedule = ScheduleItem(
            id: UUID(),
            subject: selectedSubject,
            location: selectedLocation,
            day: daysOfWeek[selectedDay],
            startTime: startTime,
            endTime: endTime
        )
        viewModel.saveSchedule(newSchedule)
        dismiss()
    }

}

struct EditScheduleView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedSchedule: ScheduleItem

    init(viewModel: ProfileViewModel, schedule: ScheduleItem) {
        self.viewModel = viewModel
        _editedSchedule = State(initialValue: schedule)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: SubjectPickerView(viewModel: viewModel, selectedSubject: $editedSchedule.subject)) {
                        Text( editedSchedule.subject)
                                  .foregroundStyle(.orange)
                          }
                    NavigationLink(destination: RoomLocationView(selectedLocation: $editedSchedule.location)) {
                        Text( editedSchedule.location)
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    Picker("Hari", selection: $editedSchedule.day) {
                        ForEach(viewModel.dayOrder, id: \.self) { day in
                            Text(day).tag(day)
                        }
                    }
                }
                Section {
                    DatePicker("Jam Mulai", selection: $editedSchedule.startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Jam Selesai", selection: $editedSchedule.endTime, displayedComponents: .hourAndMinute)
                }
            }
            .navigationBarTitle("Edit", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Batal") { dismiss() },
                trailing: Button("Simpan") {
                    viewModel.updateSchedule(editedSchedule)
                    dismiss()
                }
            )
        }
    }
}

struct SubjectPickerView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var selectedSubject: String
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode

    var filteredSubjects: [String] {
        if searchText.isEmpty {
            return viewModel.subjects
        } else {
            return viewModel.subjects.filter { $0.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSubjects, id: \.self) { subject in
                    Button(action: {
                        selectedSubject = subject
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(subject)
                            .foregroundColor(.black)
                    }
                }
            }
            .navigationBarTitle("Pilih Mata Kuliah", displayMode: .large)
            .searchable(text: $searchText, prompt: "Cari mata kuliah")
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
    @Binding var selectedLocation: String
    @Environment(\.presentationMode) var presentationMode


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
                        selectedLocation = value
                        presentationMode.wrappedValue.dismiss()
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

struct ScheduleView: View {
    @State private var selectedSegment = 0
    let segments = ["Singkat", "Semua"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Your main content goes here
                Text("Schedule content for \(segments[selectedSegment])")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()
            }
            .navigationTitle("Jadwal")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Picker("Schedule", selection: $selectedSegment) {
                            ForEach(0..<segments.count, id: \.self) { index in
                                Text(segments[index])
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 220)
                    }
                }
            }
        }
    }
}
