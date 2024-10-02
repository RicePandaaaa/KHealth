from typing import List
import matplotlib.pyplot as plt
from glucose_data import Glucose_Data


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
        self.BACKGROUND_COLOR = "#162b34"
        self.TEXT_COLOR = "#ffffff"
        self.HEADER_COLOR = "#48fcf1"
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
        plt.grid(zorder=0)
        plt.scatter(x_indices, levels, color=self.POINT_COLOR, zorder=3)
        plt.plot(x_indices, levels, linestyle="-", color=self.POINT_COLOR, linewidth=0.5, zorder=2)

        # Add the string labels to the x-axis with a slant (45 degrees)
        plt.xticks(x_indices, labels, color=self.TEXT_COLOR, rotation=45, ha="right")  # 'ha' adjusts horizontal alignment
        plt.yticks(color=self.TEXT_COLOR)

        # Add horizontal lines for safe levels
        plt.axhline(y=self.MIN_SAFE_LEVEL_MG_DL, color="black", zorder=2)
        plt.axhline(y=self.MAX_SAFE_LEVEL_MG_DL, color="black", zorder=2)

        # Adjust y-axis limits
        y_min = min(self.MIN_SAFE_LEVEL_MG_DL, min(levels)) - 5
        y_max = max(self.MAX_SAFE_LEVEL_MG_DL, max(levels)) + 5
        plt.ylim(y_min, y_max)

        # Highlight healhty (light green) and unhealthy (light red) zones
        plt.axhspan(self.MIN_SAFE_LEVEL_MG_DL, self.MAX_SAFE_LEVEL_MG_DL, color="#ccffcc", zorder=1)
        plt.axhspan(self.MAX_SAFE_LEVEL_MG_DL, y_max, color="#ffcccc", zorder=1)
        plt.axhspan(y_min, self.MIN_SAFE_LEVEL_MG_DL, color="#ffcccc", zorder=1)

        # Add labels and title and grid
        plt.xlabel(x_label, color=self.TEXT_COLOR)
        plt.ylabel("Blood Glucose Level (mg/dL)", color=self.TEXT_COLOR)
        plt.title(title, color=self.TEXT_COLOR)

        # Show the plot
        plt.tight_layout()  # Adjust layout to prevent clipping of tick labels
        plt.savefig(f"images/{file_name}")
        plt.show()


# Test code
if __name__ == "__main__":
    visualizer = Visualizer()
    data_class = Glucose_Data("glucose_time_data.csv")

    readings = data_class.get_all_readings()
    labels = [f"{reading["date"]}, {reading["time"]}" for reading in readings]
    levels = [reading["level"] for reading in readings]

    visualizer.generate_glucose_line_graph(labels, levels, "Glucose Readings", "Date", "all_readings")
