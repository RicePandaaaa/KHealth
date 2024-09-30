import csv
from typing import List, Dict, Union

class Glucose_Data():
    """Holds data and methods of adjusting and reading data

    This class revolves around being able to edit the glucose data CSV
    to reflect new measurements and being able to read the file in order
    to properly extract the information to send to other .py files for
    processing and visualization.
    """

    def __init__(self, file_name: str) -> None:
        """
        Intializes using the data file for processing

        Arguments:
            file_name: Name of the data file
        """

        # File reader
        self.file = open(file_name, "r")
        self.reader = csv.reader(self.file)

        # Data
        self.readings = []
        self.process_readings()
        self.daily_readings = []

        print(self.readings)

        self.file.close()

    def process_readings(self) -> None:
        """
        Update self.readings to contain all the data from the data file
        """

        # Skip headers
        next(self.reader)

        # Put each line into self.readings
        for row in self.reader:
            data = {"date": row[0], "level": float(row[1])}
            self.readings.append(data)


    def get_recent_readings(self, num_readings: int) -> List[Dict[str, Union[str, float]]]:
        """
        Return a certain amount of the most recent readings

        Arguments:
            num_readings: How many readings to send back
        """

        # Not enough readings, return everthing
        if num_readings > len(self.readings):
            return self.readings
        
        # Return the right most readings
        return self.readings[-num_readings]
    
    def generate_daily_average_readings(self) -> None:
        """
        Condenses self.readings into one entry per day instead,
        where the associated glucose level is the average of all the levels
        for that day
        """

        current_date = ""
        current_levels = []
        for reading in self.readings:
            # Get date
            date = reading["date"]
            level = reading["level"]

            # If current date is a placeholder, put date in
            if current_date == "":
                current_date = date

            # If date is different from current date, make average
            if date != current_date:
                average_level = sum(current_levels)/len(current_levels)
                average_reading = {"date": current_date, "level": average_level}

                # Add to self.daily_readings and update new current date and clear current levels
                self.daily_readings.append(average_reading)
                current_levels = []

            # Add the level
            current_levels.append(level)


# For testing
if __name__ == "__main__":
    Glucose_Data("glucose_time_data.csv")