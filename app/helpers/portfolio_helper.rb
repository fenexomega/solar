module PortfolioHelper

  # recupera o icone correspondente ao tipo de arquivo
  def icon_attachment(file)
    case File.extname(file)
      when '.pdf'
        'icon_file_pdf.png'
      when '.doc', '.docx'
        'icon_file_doc.png'
      when '.txt'
        'icon_file_text.png'
      else
        'icon_file_without_format.png'
    end
  end

end