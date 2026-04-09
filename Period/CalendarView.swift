//
//  SwiftUIView.swift
//  Period
//
//  Created by Elyse Q on 4/7/26.
//

import SwiftUI

struct Calendar: View {
//    @State private var currentMonth = Date()
//        let calendar = Calendar.current
//
//        let columns = Array(repeating: GridItem(.flexible()), count: 7)
//        let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
//
//        var body: some View {
//            VStack {
//                Text(monthYearString(from: currentMonth))
//                    .font(.title)
//                    .padding()
//
//                LazyVGrid(columns: columns) {
//                    ForEach(weekdaySymbols, id: \.self) { day in
//                        Text(day)
//                            .fontWeight(.bold)
//                    }
//
//                    ForEach(daysInMonth(), id: \.self) { value in
//                        if value == 0 {
//                            Text("")
//                                .frame(height: 40)
//                        } else {
//                            Text("\(value)")
//                                .frame(maxWidth: .infinity, minHeight: 120)
//                                .background(Color.yellow.opacity(0.15))
//                                .cornerRadius(10)
//                            //if selected, turn background pink
//                        }
//                    }
//                }
//                .padding()
//            }
//        }
//
//        func monthYearString(from date: Date) -> String {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "MMMM yyyy"
//            return formatter.string(from: date)
//        }
//
//        func daysInMonth() -> [Int] {
//            guard
//                let monthRange = calendar.range(of: .day, in: .month, for: currentMonth),
//                let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
//            else {
//                return []
//            }
//
//            let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
//
//            var days: [Int] = []
//
//            for _ in 1..<firstWeekday {
//                days.append(0)
//            }
//
//            for day in monthRange {
//                days.append(day)
//            }
//
//            return days
//        }
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var showingEditor = false

    // Stores info for each day
    @State private var entries: [Date: DayEntry] = [:]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

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
        }
        .animation(.easeInOut, value: showingEditor)
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
        return !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !entry.symptoms.isEmpty
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
}

// MARK: - Day Entry Model

struct DayEntry: Equatable {
    var note: String = ""
    var symptoms: Set<String> = []
}

// MARK: - Calendar Day Cell

struct DayCellView: View {
    let date: Date
    let isToday: Bool
    let hasEntry: Bool
    let dayNumber: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.body)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(.primary)

                if hasEntry {
                    Circle()
                        .fill(Color.pink.opacity(0.5)) //color of system mark circle
                        .frame(width: 7, height: 7)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 101) //edit sizes of boxes here
            .background(isToday ? Color.blue.opacity(0.25) : Color.gray.opacity(0.08)) //change background of current day
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sticky Note Pop-up

struct StickyNoteEditorView: View {
    let date: Date
    @Binding var existingEntry: DayEntry
    let onClose: () -> Void

    let symptomOptions = [
        "Period",
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

                Button("Done") {
                    onClose()
                }
                .fontWeight(.semibold)
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
                existingEntry.note = ""
                existingEntry.symptoms.removeAll()
            } label: {
                Text("Clear This Day")
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

#Preview {
    Calendar()
}
