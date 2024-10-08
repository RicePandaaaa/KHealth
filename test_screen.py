from typing import Dict, Union
from PyQt6 import uic
from PyQt6.QtWidgets import QApplication, QLabel, QMainWindow, QPushButton, QTextEdit
from PyQt6.QtGui import QPixmap, QIcon
import sys

class MainWindow(QMainWindow):
    def __init__(self,
                 all_data: Dict[str, Union[str, str, float]],
                 day_data: Dict[str, Union[str, str, float]],
                 week_data: Dict[str, Union[str, str, float]],
                 month_data: Dict[str, Union[str, str, float]]) -> None :
        
        """
        Initialize the window and starting state

        Arguments:
            day_data: Dictionary for readings of the day
            week_data: Dictionary for readings of the week
            month_data: Dictionary for readings of the month
        """

        # Initialize parent
        super(MainWindow, self).__init__()
        # Load the UI from the .ui file
        self.ui = uic.loadUi("user_interface.ui", self)

        # Store the data
        self.all_data = all_data
        self.day_data = day_data
        self.week_data = week_data
        self.month_data = month_data

        # Useful constants
        self.BACKGROUND_COLOR = "#262a33"

        # Access specific widgets using their object names from the .ui file
        self.graph_label = self.findChild(QLabel, "graphLabel")
        self.data_text_box = self.findChild(QTextEdit, "dataTextBox")

        self.day_min_val_label = self.findChild(QLabel, "dayMinValLabel")
        self.day_avg_val_label = self.findChild(QLabel, "dayAvgValLabel")
        self.day_max_val_label = self.findChild(QLabel, "dayMaxValLabel")

        self.week_min_val_label = self.findChild(QLabel, "weekMinValLabel")
        self.week_avg_val_label = self.findChild(QLabel, "weekAvgValLabel")
        self.week_max_val_label = self.findChild(QLabel, "weekMaxValLabel")

        self.month_min_val_label = self.findChild(QLabel, "monthMinValLabel")
        self.month_avg_val_label = self.findChild(QLabel, "monthAvgValLabel")
        self.month_max_val_label = self.findChild(QLabel, "monthMaxValLabel")

        self.set_to_daily_button = self.findChild(QPushButton, "dailyButton")
        self.set_to_weekly_button = self.findChild(QPushButton, "weeklyButton")
        self.set_to_monthly_button = self.findChild(QPushButton, "monthlyButton")

        # Connect the buttons
        self.set_to_daily_button.clicked.connect(lambda: self.on_button_click("daily_readings.png",
                                                                              self.day_data))
        self.set_to_weekly_button.clicked.connect(lambda: self.on_button_click("weekly_readings.png",
                                                                               self.week_data))
        self.set_to_monthly_button.clicked.connect(lambda: self.on_button_click("monthly_readings.png",
                                                                                self.month_data))

        # Window initialization
        self.setStyleSheet(f"background-color: {self.BACKGROUND_COLOR};")
        self.setWindowTitle("KHealth User Interface")
        self.setWindowIcon(QIcon("images/logo.png"))

        # Image loading
        self.load_image(self.graph_label, "daily_readings.png")

        # Text loading
        self.change_readings_text(self.day_data)

        # Show the UI
        self.show()

    def load_image(self, label: QLabel, image_filename: str):
        """
        Loads an image into the graph QLabel

        Arguments:
            label: The QLabel that will contain the image
            image_filename: File name of the image of the graph
        """

        pixmap = QPixmap(f"images/{image_filename}")
        label.setPixmap(pixmap)
        label.setScaledContents(True)

    def change_readings_text(self, data_dict: Dict[str, Union[str, str, float]]) -> None:
        """
        Changes the text displayed in the big text box of readings

        Arguments:
            data_dict: A dictionary of data to process and parse into text
        """

        # Open and edit the data
        big_string = ""
        for reading in data_dict:
            big_string += f"Date: {reading["date"]}, Time: {reading["time"]}, Level: {reading["level"]} mg/dL\n"
        big_string = big_string.strip()

        # Replace into text box
        self.data_text_box.setPlainText(big_string)

    def on_button_click(self, image_filename: str, data_dict: Dict[str, Union[str, str, float]]) -> None:
        """
        Internal function for button click functionality

        Arguments:
            image_filename: Name of graph image file to load
            data_dict: Dictionary of readings data that will be sent to helper function
        """

        # Load the new graph image
        self.load_image(self.graph_label, image_filename)
        # Change the readings text to match the newly displayed graph
        self.change_readings_text(data_dict)

if __name__ == "__main__":
    # Initialize the application
    app = QApplication(sys.argv)
    window = MainWindow()
    sys.exit(app.exec())
