import sys
import re
from io import BytesIO
import qrcode
from PySide6.QtWidgets import (
    QApplication,
    QMainWindow,
    QVBoxLayout,
    QWidget,
    QMenu,
    QFileDialog,
    QMessageBox,
    QLabel,
)
from PySide6.QtGui import QPixmap, QImage, QKeyEvent, QAction, QScreen
from PySide6.QtCore import Qt, QUrl, QSettings, QDir, QFileInfo
from PySide6.QtGui import QDesktopServices
from PIL import Image, ImageDraw, ImageFont


def extract_last_url(text):
    url_pattern = r'(https?://[^\s"]+)'
    urls = re.findall(url_pattern, text)
    if urls:
        return urls[-1]
    return None


def generate_qr(url):
    qr = qrcode.QRCode(version=1, box_size=10, border=4)
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    
    # Add URL text to the bottom white margin
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arialbd.ttf", 16)  # Bold Arial, larger size
    except IOError:
        try:
            font = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
        except IOError:
            try:
                font = ImageFont.truetype("arial.ttf", 16)
            except IOError:
                try:
                    font = ImageFont.truetype("DejaVuSans.ttf", 16)
                except IOError:
                    font = ImageFont.load_default().font_variant(size=16)
    
    # Truncate URL if too long
    display_url = url
    bbox = draw.textbbox((0, 0), display_url, font=font)
    text_width = bbox[2] - bbox[0]
    img_width, img_height = img.size
    max_text_width = img_width - 20  # Less margin for larger text
    
    while text_width > max_text_width and len(display_url) > 10:
        display_url = display_url[:-1]
        bbox = draw.textbbox((0, 0), display_url + "...", font=font)
        text_width = bbox[2] - bbox[0]
    if len(display_url) < len(url):
        display_url += "..."
    
    # Text height
    text_height = bbox[3] - bbox[1]
    
    # Position: center bottom, within the border
    x = (img_width - text_width) / 2
    y = img_height - text_height - 20  # More space from bottom
    
    draw.text((x, y), display_url, font=font, fill="black")
    
    buffer = BytesIO()
    img.save(buffer, format="PNG")
    buffer.seek(0)
    return buffer.getvalue()


class QRLabel(QLabel):
    def __init__(self, url, parent=None):
        super().__init__(parent)
        self.url = url
    
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            QDesktopServices.openUrl(QUrl(self.url))
            self.window().close()
        elif event.button() == Qt.RightButton:
            menu = QMenu(self)
            save_action = QAction("Save QR", self)
            save_action.triggered.connect(self.save_qr)
            menu.addAction(save_action)
            menu.exec(event.globalPosition().toPoint())
        super().mousePressEvent(event)
    
    def save_qr(self):
        settings = QSettings("QRGenerator", "App")
        last_dir = settings.value("last_dir", QDir.homePath())
        
        try:
            file_path, _ = QFileDialog.getSaveFileName(self, "Save QR Code", f"{last_dir}/qr.png", "PNG Files (*.png)")
            if file_path:
                qr_data = generate_qr(self.url)
                with open(file_path, "wb") as f:
                    f.write(qr_data)
                dir_path = QFileInfo(file_path).path()
                settings.setValue("last_dir", dir_path)
                QMessageBox.information(self.window(), "Saved", "QR code saved successfully!")
            else:
                # If canceled, do nothing
                pass
        except Exception as e:
            QMessageBox.warning(self.window(), "Error", f"Failed to save QR code: {str(e)}")


class QRWindow(QMainWindow):
    def __init__(self, qr_image_data, url):
        super().__init__()
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)  # Removed Qt.Popup to allow dialogs
        
        image = QImage.fromData(qr_image_data)
        pixmap = QPixmap.fromImage(image)
        
        label = QRLabel(url, self)
        label.setPixmap(pixmap.scaled(300, 300, Qt.KeepAspectRatio))
        label.setAlignment(Qt.AlignCenter)
        
        layout = QVBoxLayout()
        layout.addWidget(label)
        layout.setContentsMargins(0, 0, 0, 0)
        
        central_widget = QWidget()
        central_widget.setLayout(layout)
        self.setCentralWidget(central_widget)
        
        # Size and center the window
        self.resize(300, 300)
        screen = QScreen.availableGeometry(QApplication.primaryScreen())
        self.move((screen.width() - self.width()) // 2, (screen.height() - self.height()) // 2)
    
    def keyPressEvent(self, event: QKeyEvent):
        if event.key() == Qt.Key_Escape:
            self.close()
    
    def closeEvent(self, event):
        super().closeEvent(event)
        QApplication.quit()  # Explicitly quit the app


if __name__ == "__main__":
    app = QApplication(sys.argv)
    
    clipboard_text = app.clipboard().text() or ''
    clipboard_text = clipboard_text.strip()
    
    url = extract_last_url(clipboard_text)
    
    if not url:
        sys.exit(1)  # Exit silently if no URL
    
    qr_data = generate_qr(url)
    
    window = QRWindow(qr_data, url)
    window.show()
    sys.exit(app.exec())