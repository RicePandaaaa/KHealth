from typing import List
import matplotlib.pyplot as plt
from glucose_data import GlucoseData


class Visualizer():
    """ Visualizes data using various types of graphs and stats

    This class will take the blood glucose data and display it
    in ways that are easy to read and to interpret.
    """

    def __init__(self) -> None:
        """
        Initializes the class and any constants
        """

        # WHO's recommendations for safe blood glucose levels
        self.MIN_SAFE_LEVEL_MG_DL = 70
        self.MAX_SAFE_LEVEL_MG_DL = 100

        # Theme colors to match logo
        self.BACKGROUND_COLOR = "#23262e"
        self.TEXT_COLOR = "#ffffff"
        self.HEADER_COLOR = "#01e8c6"
        self.POINT_COLOR = "#0000ff"

    def generate_glucose_line_graph(self, labels: List[str], levels: List[float], 
                                    title: str, x_label: str, file_name: str) -> None:
        """
        Generates a glucose line graph (connecting the points with lines). Graph will include
        lines to show the zones of healthy and unhealthy blood glucose levels.

        Arguments:
            labels: List of labels for each corresponding (by index) level (can be date, time, etc.)
            levels: List of blood glucose levels
            title: Name of the graph title
            x_label: Name of the x axis label
            y_label: Name of the y axis label
            file_name: Name to use for the saved image file
        """

        # Create numerical x values (indices)
        x_indices = range(len(labels))

        # Set colors
        plt.gcf().set_facecolor(self.BACKGROUND_COLOR)

        # Create the scatter plot and line
        plt.grid(True, axis='y', zorder=0)
        # Swap to bar if there's too many values
        if len(x_indices) > 25:
            plt.bar(x_indices, levels, color=self.POINT_COLOR, zorder=3)
        else:
            plt.scatter(x_indices, levels, color=self.POINT_COLOR, zorder=3)
            plt.plot(x_indices, levels, linestyle="-", color=self.POINT_COLOR, linewidth=0.5, zorder=2)

        # Add the string labels to the x-axis with a slant (45 degrees)
        empty_labels = ["" for _ in range(len(labels))]
        plt.xticks(x_indices, empty_labels, color=self.TEXT_COLOR, rotation=45, ha="right")
        plt.yticks(color=self.TEXT_COLOR)

        # Add horizontal lines for safe levels
        plt.axhline(y=self.MIN_SAFE_LEVEL_MG_DL, color="black", zorder=2)
        plt.axhline(y=self.MAX_SAFE_LEVEL_MG_DL, color="black", zorder=2)

        # Adjust x-axis limits
        x_min = min(x_indices)
        x_max = max(x_indices)
        plt.xlim(x_min, x_max)

        # Adjust y-axis limits
        y_min = min(self.MIN_SAFE_LEVEL_MG_DL, min(levels))
        y_max = max(self.MAX_SAFE_LEVEL_MG_DL, max(levels))

        # Set to nearest multiple of 5 and ensure the min is no more than 65 and the max is no less than 105 
        y_min -= y_min % 5
        y_max += 5 - (y_max % 5)
        y_min = min(y_min, 65)
        y_max = max(y_max, 105)
        plt.ylim(y_min, y_max)

        # Highlight healhty (light green) and unhealthy (light red) zones
        plt.axhspan(self.MIN_SAFE_LEVEL_MG_DL, self.MAX_SAFE_LEVEL_MG_DL, color="#88ff88", zorder=1)
        plt.axhspan(self.MAX_SAFE_LEVEL_MG_DL, y_max, color="#ff8888", zorder=1)
        plt.axhspan(y_min, self.MIN_SAFE_LEVEL_MG_DL, color="#ff8888", zorder=1)

        # Add labels and title and grid
        plt.xlabel(x_label, color=self.HEADER_COLOR)
        plt.ylabel("Blood Glucose Level (mg/dL)", color=self.HEADER_COLOR)
        plt.title(f"{title}\n{labels[0]} to {labels[-1]}", color=self.HEADER_COLOR)

        # Show the plot
        plt.tight_layout()  # Adjust layout to prevent clipping of tick labels
        plt.savefig(f"images/{file_name}")
        plt.close()


# Test code
if __name__ == "__main__":
    visualizer = Visualizer()
    data_class = GlucoseData("glucose_time_data.csv")

    # All time readings
    readings = data_class.get_all_readings()
    labels = [f"{reading["date"]}, {reading["time"]}" for reading in readings]
    levels = [reading["level"] for reading in readings]

    visualizer.generate_glucose_line_graph(labels, levels, "All Glucose Readings", "Time", "all_readings")

    # Daily readings
    daily_readings = data_class.get_saved_daily_readings()
    daily_labels = [f"{daily_reading["date"]}, {daily_reading["time"]}" for daily_reading in daily_readings]
    daily_levels = [daily_reading["level"] for daily_reading in daily_readings]

    visualizer.generate_glucose_line_graph(daily_labels, daily_levels, "Today's Glucose Readings", "Time", "daily_readings")

    # Weekly time readings
    weekly_readings = data_class.get_saved_weekly_readings()
    weekly_labels = [f"{weekly_reading["date"]}, {weekly_reading["time"]}" for weekly_reading in weekly_readings]
    weekly_levels = [weekly_reading["level"] for weekly_reading in weekly_readings]

    visualizer.generate_glucose_line_graph(weekly_labels, weekly_levels, f"Weekly Glucose Readings", "Time", "weekly_readings")

    # Monthly readings
    monthly_readings = data_class.get_saved_monthly_readings()
    monthly_labels = [f"{monthly_reading["date"]}, {monthly_reading["time"]}" for monthly_reading in monthly_readings]
    monthly_levels = [monthly_reading["level"] for monthly_reading in monthly_readings]

    visualizer.generate_glucose_line_graph(monthly_labels, monthly_levels, "Monthly Glucose Readings", "Time", "monthly_readings")

