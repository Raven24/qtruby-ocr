
require 'Qt'
require 'tesseract'

class OutputDialog < Qt::Dialog
  def initialize
    super

    @text_view = Qt::PlainTextEdit.new
    @text_view.read_only = true

    @ok_icon = $qApp.style.standard_icon(Qt::Style::SP_DialogOkButton)
    @ok_button = Qt::PushButton.new(@ok_icon, "Done")

    connect(@ok_button, SIGNAL(:pressed), self, SLOT(:accept))

    @button_layout = Qt::HBoxLayout.new
    @button_layout.add_stretch
    @button_layout.add_widget(@ok_button)

    @button_widget = Qt::Widget.new
    @button_widget.layout = @button_layout

    @main_layout = Qt::VBoxLayout.new
    @main_layout.add_widget(@text_view)
    @main_layout.add_widget(@button_widget)

    set_layout(@main_layout)
  end

  def set_text(text)
    @text_view.plainText = text
  end

  def sizeHint
    Qt::Size.new(750, 400)
  end
end

class SelectionOcrDialog < Qt::Dialog
  def initialize
    super

    @scene = Qt::GraphicsScene.new
    @view = Qt::GraphicsView.new(@scene)

    @text = Qt::Label.new("Do you want to OCR the current selection?")
    @text.alignment = Qt::AlignCenter

    @content_layout = Qt::HBoxLayout.new
    @content_layout.add_widget(@view, 2)
    @content_layout.add_widget(@text, 3)

    @content_widget = Qt::Widget.new
    @content_widget.layout = @content_layout

    @yes_icon = $qApp.style.standard_icon(Qt::Style::SP_DialogYesButton)
    @yes_button = Qt::PushButton.new(@yes_icon, "Yes")
    @no_icon = $qApp.style.standard_icon(Qt::Style::SP_DialogNoButton)
    @no_button  = Qt::PushButton.new(@no_icon, "No")

    connect(@yes_button, SIGNAL(:pressed), self, SLOT(:accept))
    connect(@no_button,  SIGNAL(:pressed), self, SLOT(:reject))

    @button_layout = Qt::HBoxLayout.new
    @button_layout.add_stretch
    @button_layout.add_widget(@yes_button)
    @button_layout.add_widget(@no_button)

    @button_widget = Qt::Widget.new
    @button_widget.layout = @button_layout

    @main_layout = Qt::VBoxLayout.new
    @main_layout.add_widget(@content_widget)
    @main_layout.add_widget(@button_widget)

    set_layout(@main_layout)
  end

  def set_image(pixmap)
    @item = Qt::GraphicsPixmapItem.new(pixmap)
    @scene.add_item(@item)
  end

  def paintEvent(evt)
    @view.fit_in_view(@item, Qt::KeepAspectRatio) unless @item.nil?
  end

  def sizeHint
    Qt::Size.new(750, 400)
  end
end

class ImageView < Qt::GraphicsView

  signals 'selection_rect(QRect)'

  def mousePressEvent(evt)
    @selection_start = evt.pos

    unless @rubber_band.nil?
      @rubber_band.dispose
    end

    @rubber_band = Qt::RubberBand.new(Qt::RubberBand::Rectangle, self)
    @rubber_band.set_geometry(Qt::Rect.new(@selection_start, Qt::Size.new))
    @rubber_band.show

    super
  end

  def mouseMoveEvent(evt)
    @selection_curr = evt.pos

    unless @rubber_band.nil?
      @rubber_band.set_geometry(Qt::Rect.new(@selection_start, @selection_curr).normalized)
    end
  end

  def mouseReleaseEvent(evt)
    @selection_end = evt.pos

    @rect = @rubber_band.geometry
    @scene_rect = map_to_scene(@rect).bounding_rect

    puts "rect: #{@scene_rect.inspect}"

    emit selection_rect(@scene_rect.to_rect)
    super
  end

  def remove_selection
    @rubber_band.dispose unless @rubber_band.nil?
  end
end

class ImageWidget < Qt::Widget

  signals 'crop_selection(QPixmap, QRect)',
          :next_image,
          :previous_image

  slots :remove_selection,
        'image_selection(QRect)',
        'image_rotation(int)'

  def initialize
    super

    @scene = Qt::GraphicsScene.new
    @view = ImageView.new(@scene)

    @rotate_label = Qt::Label.new("Rotate")
    @rotate_spinbox = Qt::SpinBox.new
    @rotate_spinbox.enabled = false
    @rotate_spinbox.value = 0
    @rotate_spinbox.set_range(-359, 359)

    @rotate_layout = Qt::HBoxLayout.new
    @rotate_layout.add_widget(@rotate_label)
    @rotate_layout.add_widget(@rotate_spinbox)

    @rotate_widget = Qt::Widget.new
    @rotate_widget.layout = @rotate_layout

    @next_icon = $qApp.style.standard_icon(Qt::Style::SP_ArrowForward)
    @next_button = Qt::PushButton.new(@next_icon, "Next")
    @next_button.enabled = false
    @previous_icon = $qApp.style.standard_icon(Qt::Style::SP_ArrowBack)
    @previous_button = Qt::PushButton.new(@previous_icon, "Previous")
    @previous_button.enabled = false

    @navigator_layout = Qt::HBoxLayout.new
    @navigator_layout.add_widget(@previous_button)
    @navigator_layout.add_widget(@next_button)

    @navigator_widget = Qt::Widget.new
    @navigator_widget.layout = @navigator_layout

    @toolpane_layout = Qt::HBoxLayout.new
    @toolpane_layout.add_widget(@rotate_widget)
    @toolpane_layout.add_stretch
    @toolpane_layout.add_widget(@navigator_widget)

    @toolpane_widget = Qt::Widget.new
    @toolpane_widget.layout = @toolpane_layout

    @main_layout = Qt::VBoxLayout.new
    @main_layout.add_widget(@toolpane_widget)
    @main_layout.add_widget(@view)

    set_layout(@main_layout)

    connect(@view, SIGNAL('selection_rect(QRect)'), self, SLOT('image_selection(QRect)'))
    connect(@rotate_spinbox, SIGNAL('valueChanged(int)'), self, SLOT('image_rotation(int)'))
    connect(@next_button, SIGNAL(:pressed), self, SIGNAL(:next_image))
    connect(@previous_button, SIGNAL(:pressed), self, SIGNAL(:previous_image))
  end

  def set_image(filename)
    @rotate_spinbox.enabled = true
    @next_button.enabled = true
    @previous_button.enabled = true

    @original_image.dispose unless @original_image.nil?
    @image.dispose unless @image.nil?
    @item.dispose unless @item.nil?

    @original_image = Qt::Pixmap.new(filename)
    @image = @original_image
    @item = Qt::GraphicsPixmapItem.new(@image)

    @scene.add_item(@item)
  end

  def paintEvent(evt)
    @view.fit_in_view(@item, Qt::KeepAspectRatio) unless @item.nil?
  end

  def remove_selection
    @view.remove_selection
  end

  def image_selection(rect)
    emit crop_selection(@image, rect) unless @image.nil?
  end

  def image_rotation(degrees)
    transform = Qt::Transform.new.rotate(degrees)
    new_img = @original_image.transformed(transform)
    @item.set_pixmap(new_img)
    @image = new_img
  end
end

class AppWindow < Qt::MainWindow

  signals :ocr_finished

  slots :show_open_dialog,
        :ocr_all,
        :open_next,
        :open_previous,
        'open_image(QString)',
        'crop_selection(QPixmap, QRect)'

  def initialize
    super

    @fileMenu = Qt::Menu.new("File", self)
    @aboutMenu = Qt::Menu.new("About", self)

    @openAction = @fileMenu.add_action("Open")
    @ocrAction  = @fileMenu.add_action("OCR all")
    @quitAction = @fileMenu.add_action("Quit")

    @aboutQtAction = @aboutMenu.add_action("About Qt")

    @ocrAction.enabled = false

    menu_bar().add_menu(@fileMenu)
    menu_bar().add_menu(@aboutMenu)

    @view = ImageWidget.new
    set_central_widget(@view)


    connect(@openAction, SIGNAL(:triggered), self, SLOT(:show_open_dialog))
    connect(@ocrAction,  SIGNAL(:triggered), self, SLOT(:ocr_all))
    connect(@quitAction, SIGNAL(:triggered), self, SLOT(:close))
    connect(@aboutQtAction, SIGNAL(:triggered), $qApp, SLOT(:aboutQt))
    connect(@view, SIGNAL('crop_selection(QPixmap, QRect)'), self, SLOT('crop_selection(QPixmap, QRect)'))
    connect(@view, SIGNAL(:next_image), self, SLOT(:open_next))
    connect(@view, SIGNAL(:previous_image), self, SLOT(:open_previous))
    connect(self, SIGNAL(:ocr_finished), @view, SLOT(:remove_selection))
  end

  def show_open_dialog
    @dialog = Qt::FileDialog.new(self, "Open image", Dir.home, "Images (*.png *.xpm *.jpg)")

    connect(@dialog, SIGNAL('fileSelected(QString)'), self, SLOT('open_image(QString)'))

    @dialog.exec
    @dialog.dispose
  end

  def open_image(filename)
    @image_filename = filename
    @ocrAction.enabled = true

    puts "opening #{@image_filename}"

    @view.set_image(@image_filename)
  end

  def directory_list_pos
    dir = File.dirname(@image_filename)
    list = Dir.glob(File.join(dir, '*'))
            .select { |f| !Dir.exists?(f) }
            .map { |f| File.basename(f) }
            .sort_by { |f| f.downcase }
    idx = list.index(File.basename(@image_filename))
    [idx, list, dir]
  end

  def open_next
    idx, list, dir = directory_list_pos
    n_idx = idx+1
    if n_idx >= list.length
      Qt::MessageBox.warning(self, "EOL", "End of the folder.\nThere are no more images...")
    else
      open_image(File.join(dir, list[n_idx]))
    end
  end

  def open_previous
    idx, list, dir = directory_list_pos
    p_idx = idx-1
    if p_idx <= 0
      Qt::MessageBox.warning(self, "EOL", "Beginning of the folder.\nThere are no more images...")
    else
      open_image(File.join(dir, list[p_idx]))
    end
  end

  def ocr_all
    start_ocr(@image_filename)
  end

  def start_ocr(filename)
    puts "doing ocr on #{filename}"
    puts "please wait ..."

    engine = Tesseract::Engine.new do |e|
      e.language = :deu
      e.blacklist = '|'
    end

    text = engine.text_for(filename).strip
    text.encode!(Encoding.find("ISO-8859-1"), invalid: :replace, undef: :replace, replace: '?')

    puts "done"

    @dialog = OutputDialog.new
    @dialog.set_text(text)
    @dialog.exec
    @dialog.dispose
  end

  def crop_selection(pixmap, rect)
    puts "creating cropped image..."
    puts "rect: #{rect.inspect}"

    cropped_img = pixmap.copy(rect)

    tmp_dir = Dir.tmpdir
    ext = File.extname(@image_filename)
    file_prefix = File.basename(@image_filename, ext)
    tmp_name = "#{file_prefix}.#{rand(0x100000000).to_s(36)}.jpg"
    tmp_file = File.join(tmp_dir, tmp_name)

    puts "tmpfile: #{tmp_file}"

    if cropped_img.save(tmp_file, 'JPG', 92)
      puts "done"
    else
      puts "failed"
      return
    end

    selection_ocr_dialog(cropped_img, tmp_file)
    cropped_img.dispose
  end

  def selection_ocr_dialog(pixmap, filename)
    @dialog = SelectionOcrDialog.new
    @dialog.set_image(pixmap)
    if @dialog.exec == Qt::Dialog::Accepted
      start_ocr(filename)
    end
    @dialog.dispose

    File.unlink(filename)

    emit ocr_finished
  end
end


#Qt.debug_level = Qt::DebugLevel::High

a = Qt::Application.new(ARGV)

win = AppWindow.new
win.show
win.resize(900,650)

a.exec
