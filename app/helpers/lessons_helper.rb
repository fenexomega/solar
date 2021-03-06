module LessonsHelper

  def lessons_by_module(lesson_module_id)
    Lesson.joins(:lesson_module, :schedule).where(lesson_modules: {id: lesson_module_id}).order("lessons.order")
  end

  def lessons_list(lessons, atual_id_open = nil)
    count, total_lesson = 1, lessons.length
    order_lesson, text = '', ''

    lessons.each do |l|
      order_lesson = (atual_id_open == l.lesson_id) ? count.to_s : order_lesson.to_s
      path_lesson  = l.type_lesson == 1 ? l.address : "/media/lessons/#{l.lesson_id}/#{l.address}"
      text_lesson  = [t(:lesson, :scope => [:lessons, :list]), ' ', count.to_s, ' - ', total_lesson.to_s].join('')

      unless ((l.schedule.end_date.nil?) or (l.schedule.end_date.to_date < Date.today)) and (l.schedule.start_date.to_date > Date.today)
        text << "<span class='lesson_link' id='lesson_link#{count.to_s}' data-path='#{path_lesson}' data-text_lesson='#{URI.escape(text_lesson)}' data-count='#{count.to_s}'>"+count.to_s+"</span>" 
      end

      count = count + 1
    end

    return text, order_lesson, total_lesson
  end

  def files_and_folders(lesson)
    file = lesson.path(true, false).to_s

    @files = directory_hash(file, lesson.name).to_json
    @folders = directory_hash(file, lesson.name, false).to_json
  end

end
