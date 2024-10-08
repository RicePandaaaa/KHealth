from PyQt6 import uic
from PyQt6.QtWidgets import QApplication, QLabel, QMainWindow
from PyQt6.QtGui import QPixmap, QIcon
import sys

class MainWindow(QMainWindow):
    def __init__(self):
        super(MainWindow, self).__init__()
        # Load the UI from the .ui file
        self.ui = uic.loadUi("user_interface.ui", self)

        # Useful constants
        self.BACKGROUND_COLOR = "#262a33"

        # Access specific widgets using their object names from the .ui file
        self.graph_label = self.findChild(QLabel, "graphLabel")
        self.logo_label = self.findChild(QLabel, "logoLabel")

        # Window initialization
        self.setStyleSheet(f"background-color: {self.BACKGROUND_COLOR};")
        self.load_image(self.graph_label, "all_readings.png")
        self.setWindowTitle("KHealth User Interface")
        self.setWindowIcon(QIcon("images/logo.png"))

        # Show the UI
        self.show()

    def load_image(self, label, image_filename: str):
        """
        Loads an image into the graph QLabel

        Arguments:
            label: The QLabel that will contain the image
            image_filename: File name of the image of the graph
        """
        pixmap = QPixmap(f"images/{image_filename}")
        label.setPixmap(pixmap)
        label.setScaledContents(True)  

# Initialize the application
app = QApplication(sys.argv)
window = MainWindow()
sys.exit(app.exec())
