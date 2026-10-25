import SwiftUI
import ReminderSnapCore

struct MissingDetailsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    private var courses: [String] { Array(Set(model.items.map(\.candidate.courseCode).filter { !$0.isEmpty })).sorted() }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: model.copy("A little context helps", "补充一点信息就好"))
                    Text(model.copy("Let’s finish your assignments.", "一起补全作业信息。" )).font(.title2.weight(.medium))
                }
                Spacer()
                Button(model.copy("Later", "稍后")) { dismiss() }.buttonStyle(QuietButtonStyle())
            }.padding(22)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label(model.copy("\(model.items.count) tasks found", "识别到 \(model.items.count) 项任务"), systemImage: "checklist")
                    if !model.documents.isEmpty {
                        Panel(padding: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(model.copy("Course for each image", "每张图片的课程" )).font(.headline)
                                ForEach(Array(Set(model.documents.map(\.sourceName))).sorted(), id: \.self) { source in
                                    SourceCourseChoice(source: source)
                                }
                                Text(model.copy("Correct a detected course or choose one for this image only. A new import starts fresh. Leave blank to keep tasks uncategorized.", "可修正识别课程，选择仅作用于此图片。新导入不会沿用，留空则保留为未分类。"))
                                    .font(.caption).foregroundStyle(Studio.muted)
                            }
                        }
                    }
                    if model.items.contains(where: { $0.candidate.dueDate == nil }) {
                        Panel(padding: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(model.copy("Some deadlines need details", "部分截止日期需要补充信息"), systemImage: "calendar.badge.exclamationmark")
                                TextField(model.copy("Course year, e.g. 2026", "课程年份，例如 2026"), text: $model.batchYear).studioField()
                                Text(model.copy("A screenshot may omit the year. Enter the actual course year; we won’t guess it. If a date is missing entirely, tap that task to choose one.", "截图可能没有年份。请填写真实课程年份，应用不会猜测。若完全缺少日期，请点击对应任务手动设置。"))
                                    .font(.caption).foregroundStyle(Studio.muted)
                            }
                        }
                    }
                    Picker(model.copy("Course timezone", "课程时区"), selection: $model.batchTimeZone) {
                        Text(model.copy("Use device timezone", "使用设备时区")).tag("")
                        Text("America/New_York").tag("America/New_York")
                        Text("America/Los_Angeles").tag("America/Los_Angeles")
                        Text("Asia/Shanghai").tag("Asia/Shanghai")
                        Text("UTC").tag("GMT")
                    }
                    Text(model.copy("Confirm the course’s timezone, especially if you study remotely. A screenshot without a timezone cannot tell us whether 23:59 means California, New York, or your device’s local time.", "远程学习时请特别确认课程时区。若截图没有时区，应用无法确定 23:59 指加州、纽约还是设备当地时间。"))
                        .font(.caption).foregroundStyle(Studio.muted)
                    ForEach(courses, id: \.self) { course in
                        CourseSectionPicker(course: course, sections: Array(Set(model.items.filter { $0.candidate.courseCode == course }.compactMap(\.candidate.sectionCode))).sorted())
                    }
                    Text(model.copy("Nothing is saved until you confirm. You can edit each title and deadline on the next screen.", "确认之前不会保存任何内容，下一页可逐项编辑标题和截止日期。"))
                        .font(.caption).foregroundStyle(Studio.muted)
                }.padding(22)
            }
            HStack {
                Button(model.copy("Keep uncategorized", "保留为未分类")) { dismiss() }.buttonStyle(QuietButtonStyle())
                Spacer()
                Button(model.copy("Apply & review", "应用并核对")) { model.applyBatchDetails(); dismiss() }.buttonStyle(SilverButtonStyle(small: true))
            }.padding(20)
        }.background(Studio.background).foregroundStyle(Studio.silver).preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 600, height: 690)
        #endif
    }
}

struct SourceCourseChoice: View {
    @EnvironmentObject private var model: AppModel
    let source: String
    private var detected: [String] {
        Array(Set(model.items.filter { $0.candidate.sourceImages.contains(source) }.map(\.candidate.courseCode))).filter { !$0.isEmpty }.sorted()
    }
    private var course: Binding<String> {
        Binding(get: { model.importCourseOverrides[source] ?? (detected.count == 1 ? detected[0] : "") },
                set: { model.importCourseOverrides[source] = $0 })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(source).font(.caption).foregroundStyle(Studio.muted).lineLimit(2)
            HStack {
                TextField(detected.count > 1 ? model.copy("Multiple courses detected · keep as read", "识别到多门课程 · 保留识别结果") : model.copy("Course name · optional", "课程名称 · 可选"), text: course).studioField()
                Menu {
                    ForEach(model.planner.courses.filter { $0.isArchived != true }) { profile in
                        Button(profile.name) { course.wrappedValue = profile.name }
                    }
                    Button(model.copy("Uncategorized", "未分类")) { course.wrappedValue = "" }
                } label: { Image(systemName: "chevron.down.circle").padding(8) }.accessibilityLabel(model.copy("Choose saved course", "选择已保存课程"))
            }
        }
    }
}

struct CourseSectionPicker: View {
    @EnvironmentObject private var model: AppModel
    let course: String
    let sections: [String]
    @State private var choice = ""
    var body: some View {
        if !sections.isEmpty {
            Panel(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(course).font(.headline)
                    Text(model.copy("This page contains several class sections. Which is yours?", "页面包含多个班级，请选择你所在的班级。"))
                        .font(.caption).foregroundStyle(Studio.muted)
                    Picker(model.copy("My section", "我的班级"), selection: $choice) {
                        Text(model.copy("Show all · I’ll choose tasks", "显示全部 · 手动选择任务")).tag("")
                        ForEach(sections, id: \.self) { Text($0).tag($0) }
                    }
                    Text(model.copy("Shared tasks stay visible. Other sections are filtered, not deleted.", "公共任务仍然显示，其他班级任务只会被筛选，不会删除。"))
                        .font(.caption).foregroundStyle(Studio.muted)
                }
            }
            .onAppear { choice = model.planner.courses.first { $0.id == CourseNormalizer.tag(from: course) }?.section ?? "" }
            .onValueChange(choice) { value in
                var profile = model.planner.courses.first { $0.id == CourseNormalizer.tag(from: course) } ?? CourseProfile(name: course, colorIndex: model.planner.courses.count % 8)
                profile.section = value; model.saveProfile(profile)
            }
        }
    }
}
