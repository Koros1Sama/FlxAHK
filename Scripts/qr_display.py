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
from PySide6.QtCore import Qt, QUrl, QSettings, QDir, QFileInfo, QEvent
from PySide6.QtGui import QDesktopServices
from PIL import Image, ImageDraw, ImageFont


def extract_last_url(text):
    url_pattern = r'(https?://[^\s"]+)'
    urls = re.findall(url_pattern, text)
    if urls:
        return urls[-1]
    return None


def prepare_data(text):
    text = text.strip()
    if not text:
        return None, None, None
    
    url = extract_last_url(text)
    if url:
        return url, url, "Link"
    
    # Email
    if re.match(r'^[\w\.-]+@[\w\.-]+\.\w+$', text):
        return f'mailto:{text}', text, "Email"
    
    # Phone
    if re.match(r'^\+?[\d\s-]{8,}$', text) and not re.search(r'[a-zA-Z]', text):
        cleaned = text.replace(' ', '').replace('-', '')
        return f'tel:{cleaned}', text, "Phone"
    
    # URL without scheme
    potential_url_match = re.match(r'^(www\.)?[\w\.-]+\.[\w\.-]+$', text)
    if potential_url_match:
        common_tlds = {
            'com', 'org', 'net', 'int', 'edu', 'gov', 'mil', 'io', 'co', 'uk', 'de', 'fr', 'es', 'it',
            'nl', 'se', 'no', 'dk', 'fi', 'ca', 'au', 'nz', 'jp', 'cn', 'kr', 'br', 'mx', 'app', 'blog',
            'dev', 'me', 'tv', 'cc', 'info', 'biz', 'us', 'eu', 'ru'
        }
        normalized_text = text.lower().lstrip('www.')
        parts = normalized_text.rsplit('.', 1)
        if len(parts) == 2 and parts[1] in common_tlds:
            return f'http://{text}', text, "Link"
    
    # Plain text
    return text, text, "Text"


def generate_qr(data, with_text=True, display_text=None):
    qr = qrcode.QRCode(
        version=None,  # Auto-determine the version
        error_correction=qrcode.constants.ERROR_CORRECT_L,  # Low error correction for max capacity
        box_size=10, 
        border=4
    )
    qr.add_data(data)
    qr.make(fit=True)
    version = qr.version
    img = qr.make_image(fill_color="black", back_color="white")
    
    if with_text:
        if display_text is None:
            display_text = data
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
        display_url = display_text
        bbox = draw.textbbox((0, 0), display_url, font=font)
        text_width = bbox[2] - bbox[0]
        img_width, img_height = img.size
        max_text_width = img_width - 20  # Less margin for larger text
        
        while text_width > max_text_width and len(display_url) > 10:
            display_url = display_url[:-1]
            bbox = draw.textbbox((0, 0), display_url + "...", font=font)
            text_width = bbox[2] - bbox[0]
        if len(display_url) < len(display_text):
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
    return buffer.getvalue(), version


class QRLabel(QLabel):
    def __init__(self, data, parent=None):
        super().__init__(parent)
        self.data = data
    
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            if self.data.startswith(("http://", "https://", "mailto:", "tel:")):
                QDesktopServices.openUrl(QUrl(self.data))
            else:
                app = QApplication.instance()
                app.clipboard().setText(self.data)
                QMessageBox.information(self.window(), "Copied", "Text copied to clipboard!")
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
            file_path, _ = QFileDialog.getSaveFileName(self, "Save QR Code", f"{last_dir}/qr.png", "PNG Files (*.png)", options=QFileDialog.DontUseNativeDialog)
            if file_path:
                qr_data, _ = generate_qr(self.data, with_text=True, display_text=self.window().display_text)
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
    def __init__(self, qr_image_data, data, display_text, content_type, version):
        super().__init__()
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)  # No Popup
        self.display_text = display_text
        
        image = QImage.fromData(qr_image_data)
        pixmap = QPixmap.fromImage(image)
        
        qr_label = QRLabel(data, self)
        qr_label.setAlignment(Qt.AlignCenter)
        
        # Truncate display_text for UI if too long
        display_text_truncated = display_text
        if len(display_text_truncated) > 100:
            display_text_truncated = display_text_truncated[:97] + "..."
        
        # Add type label
        type_label = QLabel(content_type + ":", self)
        type_label.setAlignment(Qt.AlignCenter)
        type_label.setStyleSheet("QLabel { color: gray; font-size: 12px; }")  # Styling for type hint
        
        # Add text label
        url_label = QLabel(display_text_truncated, self)
        url_label.setAlignment(Qt.AlignCenter)
        url_label.setWordWrap(True)  # Wrap if too long
        url_label.setStyleSheet("QLabel { color: black; font-weight: bold; font-size: 14px; }")  # Styling
        
        layout = QVBoxLayout()
        layout.addWidget(qr_label)
        layout.addWidget(type_label)
        layout.addWidget(url_label)
        layout.setContentsMargins(10, 10, 10, 10)
        layout.setSpacing(10)
        
        central_widget = QWidget()
        central_widget.setLayout(layout)
        self.setCentralWidget(central_widget)
        
        # Adaptive scaling based on QR version
        screen = QApplication.primaryScreen().availableGeometry()
        modules = 21 + 4 * (version - 1)
        target_size = (modules + 8) * 10  # Include border for consistent module size
        max_size = min(screen.width() * 0.8, screen.height() * 0.8)
        display_size = min(target_size, max_size)
        
        qr_label.setPixmap(pixmap.scaled(display_size, display_size, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        
        # Adjust window size
        self.resize(display_size + 20, display_size + 100)  # Extra space for labels and margins
        self.move((screen.width() - self.width()) // 2, (screen.height() - self.height()) // 2)
    
    def keyPressEvent(self, event: QKeyEvent):
        if event.key() == Qt.Key_Escape:
            self.close()
    
    def closeEvent(self, event):
        super().closeEvent(event)
        QApplication.quit()  # Explicitly quit the app
    
    def changeEvent(self, event):
        if event.type() == QEvent.ActivationChange:
            if not self.isActiveWindow():
                if QApplication.activeModalWidget() is None and QApplication.activePopupWidget() is None:
                    self.close()
        super().changeEvent(event)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    
    clipboard_text = app.clipboard().text() or ''
    clipboard_text = clipboard_text.strip()
    
    data, display_text, content_type = prepare_data(clipboard_text)
    
    if not data:
        sys.exit(1)  # Exit silently if no data
    
    try:
        qr_data, version = generate_qr(data, with_text=False)
    except ValueError as e:
        if "Invalid version" in str(e):
            QMessageBox.critical(None, "Error", "The text is too long to generate a QR code. Please shorten it.")
        else:
            QMessageBox.critical(None, "Error", f"Failed to generate QR code: {str(e)}")
        sys.exit(1)
    
    window = QRWindow(qr_data, data, display_text, content_type, version)
    window.show()
    sys.exit(app.exec())