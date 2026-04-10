//
//  SwiftUIView.swift
//  Period
//
//  Created by Elyse Q on 4/7/26.
//

import SwiftUI

struct CalendarView: View {
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var showingEditor = false

    // Stores info for each day
    @State private var entries: [Date: DayEntry] = [:]
    
    @State private var showCycleInfo = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let storageKey = "savedPeriodEntries"

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                headerView

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(weekdaySymbols, id: \.self) { weekday in
                        Text(weekday)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(calendarDays(), id: \.self) { date in
                        if let date = date {
                            DayCellView(
                                date: date,
                                isToday: calendar.isDateInToday(date),
                                hasEntry: hasEntry(for: date),
                                hasPeriod: hasPeriod(on: date),
                                dayNumber: dayNumber(from: date)
                            ) {
                                selectedDate = date
                                showingEditor = true
                            }
                        } else {
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(height: 52)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)

            if showingEditor, let selectedDate {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingEditor = false
                    }

                StickyNoteEditorView(
                    date: selectedDate,
                    existingEntry: bindingForDate(selectedDate),
                    onClose: {
                        showingEditor = false
                    }
                )
                .padding()
                .transition(.scale)
                .zIndex(1)
            }
            
            Button ("Cycle Facts") {
                showCycleInfo = true
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Color.purple.opacity(0.1))
            .buttonStyle(.plain)
            .cornerRadius(50)
            .offset(x: 80, y: 370)
            
            if showCycleInfo {
                CycleInfoEditorView(onClose: {
                    showCycleInfo = false
                })
            }
        }
        .animation(.easeInOut, value: showingEditor)
        .onAppear {
            loadEntries()
        }
        .onChange(of: entries) {
            saveEntries()
        }
        
    }

    // MARK: - Header

    var headerView: some View {
        HStack {
            Button {
                if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                    displayedMonth = newMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(10)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            Text(monthYearString(from: displayedMonth))
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button {
                if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                    displayedMonth = newMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding(10)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Calendar Data

    func calendarDays() -> [Date?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else {
            return []
        }

        var dates: [Date?] = []
        var currentDate = firstWeek.start

        while currentDate < lastWeek.end {
            if calendar.isDate(currentDate, equalTo: displayedMonth, toGranularity: .month) {
                dates.append(currentDate)
            } else {
                dates.append(nil)
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }

    func hasPeriod(on date: Date) -> Bool {
        let key = normalizedDate(date)
        return entries[key]?.hasPeriod ?? false
    }
    
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    func dayNumber(from date: Date) -> String {
        let day = calendar.component(.day, from: date)
        return "\(day)"
    }

    func normalizedDate(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func hasEntry(for date: Date) -> Bool {
        let key = normalizedDate(date)
        guard let entry = entries[key] else { return false }
        return entry.hasPeriod || !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !entry.symptoms.isEmpty
    }

    func bindingForDate(_ date: Date) -> Binding<DayEntry> {
        let key = normalizedDate(date)

        return Binding<DayEntry>(
            get: {
                entries[key] ?? DayEntry()
            },
            set: { newValue in
                entries[key] = newValue
            }
        )
    }

    func saveEntries() {
        let savedArray = entries.map { SavedDayEntry(date: $0.key, entry: $0.value) }

        do {
            let data = try JSONEncoder().encode(savedArray)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save entries: \(error)")
        }
    }

    func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }

        do {
            let savedArray = try JSONDecoder().decode([SavedDayEntry].self, from: data)
            entries = Dictionary(uniqueKeysWithValues: savedArray.map { ($0.date, $0.entry) })
        } catch {
            print("Failed to load entries: \(error)")
        }
    }
    
}



// MARK: - Day Entry Model

struct DayEntry: Equatable, Codable {
    var note: String = ""
    var symptoms: Set<String> = []
    var hasPeriod: Bool = false
}

struct SavedDayEntry: Codable {
    var date: Date
    var entry: DayEntry
}

// MARK: - Calendar Day Cell

struct DayCellView: View {
    let date: Date
    let isToday: Bool
    let hasEntry: Bool
    let hasPeriod: Bool
    let dayNumber: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.body)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(.primary)

                if hasEntry && !hasPeriod{
                    Circle()
                        .fill(hasPeriod ? Color.red : Color.pink.opacity(0.5))
                        .frame(width: 7, height: 7)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 101) //edit sizes of boxes here
            .background(backgroundColor) //change background of current day
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
//            if isToday{
//                .border(Color.blue, width: 4)
//            }
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    var backgroundColor: Color {
        if hasPeriod {
            return Color.red.opacity(0.25) //change background if period day
        } else if isToday {
            return Color.blue.opacity(0.25)
        } else {
            return Color.gray.opacity(0.08)
        }
    }
    
    var borderColor: Color {
        if hasPeriod && isToday {
            return Color.blue.opacity(0.35) //change border color if period day & today (to make today clear when background is pink)
        } else {
            return Color.purple.opacity(0.35)
        }
    }
    
    var borderWidth: CGFloat {
        if hasPeriod && isToday {
            return  5 //change border lineWidth size if period day & today
        } else {
            return 1
        }
    }
}

// MARK: - Sticky Note Pop-up

struct StickyNoteEditorView: View {
    let date: Date
    @Binding var existingEntry: DayEntry
    let onClose: () -> Void

    let symptomOptions = [
//        "Period",
        "Cramps",
        "Headache",
        "Bloating",
        "Fatigue",
        "Acne",
        "Back Pain",
        "Breast Tenderness",
        "Digestive Issues",
        "Cravings",
        "Mood",
        "Anxiety",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(formattedDate(date))
                    .font(.headline)

                Spacer()

                Button("Clear Day") {
                    existingEntry.note = ""
                    existingEntry.symptoms.removeAll()
                    existingEntry.hasPeriod = false
//                    onClose()
                }
                .fontWeight(.semibold)
                .tint(.red)
            }

            Text("Notes")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextEditor(text: $existingEntry.note)
                .frame(height: 120)
                .padding(8)
                .background(Color.white.opacity(0.75))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.purple.opacity(0.35), lineWidth: 1)
                )
            
            Text("Period")
                .font(.subheadline)
                .fontWeight(.semibold)

            Button {
                existingEntry.hasPeriod.toggle()
            } label: {
                HStack {
                    Image(systemName: existingEntry.hasPeriod ? "drop.fill" : "drop")
                    Text(existingEntry.hasPeriod ? "Period Logged" : "Mark as Period Day")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(existingEntry.hasPeriod ? Color.red.opacity(0.3) : Color.white.opacity(0.75))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Text("Symptoms")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                ForEach(symptomOptions, id: \.self) { symptom in
                    Button {
                        toggleSymptom(symptom)
                    } label: {
                        Text(symptom)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(existingEntry.symptoms.contains(symptom) ? Color.pink.opacity(0.35) : Color.white.opacity(0.75))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
//                existingEntry.note = ""
//                existingEntry.symptoms.removeAll()
//                existingEntry.hasPeriod = false
                onClose()

            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

        }
        .padding(20)
        //.background(Color(red: 1.0, green: 0.97, blue: 0.72))
        .background(Color.pink.brightness(0.8))
        //.background(Color.brown.brightness(0.2)) //color for pop-up
        .cornerRadius(18)
        .shadow(radius: 12)
        .frame(maxWidth: 350)
    }

    func toggleSymptom(_ symptom: String) {
        if existingEntry.symptoms.contains(symptom) {
            existingEntry.symptoms.remove(symptom)
        } else {
            existingEntry.symptoms.insert(symptom)
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
            
}

struct CycleInfoEditorView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
//                Spacer()

                Button("Done") {
                    onClose()
                }
                .fontWeight(.semibold)
                .offset(x: 265)
            }

            Text("Cycle Information")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("The menstrual cycle typically lasts for 21-35 days and has 4 main cycles- menstruation, follicular, ovulation, and luteal")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("Menstruation- ")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("Uterine lining sheds, causing bleeding. Usually lasts 3-7 days \n")
                .font(.subheadline)
            
            Text("Follicular- ")
                .font(.subheadline)
                .fontWeight(.semibold)
//                .font(.custom("Arial Rounded MT Bold", size: 18))
//                .font(.custom("Times New Roman", size: 18))
            
            Text("Starts on the first day of your period and lasts for 13-14 days. The last day of this phase is ovulation. \n")
                .font(.subheadline)
            
            Text("Ovulation- ")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("Happens once a month, about 2 weeks before your next period, on the last day of follucular. This is when you are most likely to get pregnant \n")
                .font(.subheadline)
            
            Text("Luteal- ")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("This is when- \n")
                .font(.subheadline)
        }
        .padding(20)
        //.background(Color(red: 1.0, green: 0.97, blue: 0.72))
        .background(Color.pink.brightness(0.8))
        //.background(Color.brown.brightness(0.2)) //color for pop-up
        .cornerRadius(18)
        .shadow(radius: 12)
        .frame(maxWidth: 350)
    }
}

#Preview {
    CalendarView()
}
