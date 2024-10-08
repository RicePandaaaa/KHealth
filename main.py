from PyQt6.QtWidgets import QApplication

from test_screen import MainWindow
from glucose_data import GlucoseData
from grapher import Visualizer

import sys


if __name__ == "__main__":
    # Load the data and grpahing classes
    data_class = GlucoseData("glucose_time_data.csv")
    visualizer = Visualizer()

    # ---- Create the graphs ---- #
    # All time readings
    # readings = data_class.get_all_readings()
    # print("Done grabbing all readings.")
    # labels = [f"{reading["date"]}, {reading["time"]}" for reading in readings]
    # levels = [reading["level"] for reading in readings]

    # visualizer.generate_glucose_line_graph(labels, levels, "All Glucose Readings", "Time", "all_readings")
    # print("Done creating all readings graph.")

    # Daily readings
    daily_readings = data_class.get_saved_daily_readings()
    print("Done grabbing daily readings.")
    daily_labels = [f"{daily_reading["date"]}, {daily_reading["time"]}" for daily_reading in daily_readings]
    daily_levels = [daily_reading["level"] for daily_reading in daily_readings]

    visualizer.generate_glucose_line_graph(daily_labels, daily_levels, "Today's Glucose Readings", "Time", "daily_readings")
    print("Done creating daily readings graph.")

    # Weekly time readings
    weekly_readings = data_class.get_saved_weekly_readings()
    print("Done grabbing weekly readings.")
    weekly_labels = [f"{weekly_reading["date"]}, {weekly_reading["time"]}" for weekly_reading in weekly_readings]
    weekly_levels = [weekly_reading["level"] for weekly_reading in weekly_readings]

    visualizer.generate_glucose_line_graph(weekly_labels, weekly_levels, f"Weekly Glucose Readings", "Time", "weekly_readings")
    print("Done grabbing weekly readings graph.")

    # Monthly readings
    monthly_readings = data_class.get_saved_monthly_readings()
    print("Done grabbing monthly readings.")
    monthly_labels = [f"{monthly_reading["date"]}, {monthly_reading["time"]}" for monthly_reading in monthly_readings]
    monthly_levels = [monthly_reading["level"] for monthly_reading in monthly_readings]

    visualizer.generate_glucose_line_graph(monthly_labels, monthly_levels, "Monthly Glucose Readings", "Time", "monthly_readings")
    print("Done grabbing monthly readings graph.")

    # Make the window
    app = QApplication(sys.argv)
    screen = MainWindow(None, daily_readings, weekly_readings, monthly_readings)
    sys.exit(app.exec())