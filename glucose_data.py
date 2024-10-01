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
        self.readings = []       # Contains data in form of {"date": date (str), "time": time, "level": level (float)}
        self.process_readings()
        self.daily_readings = []
        self.generate_daily_average_readings()

        self.file.close()

    def process_readings(self) -> None:
        """
        Update self.readings to contain all the data from the data file
        """

        # Skip headers
        next(self.reader)

        # Put each line into self.readings
        for row in self.reader:
            data = {"date": row[0], "time": row[1], "level": float(row[2])}
            self.readings.append(data)


    def get_recent_readings(self, num_readings: int) -> List[Dict[str, Union[str, str, float]]]:
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

        # Categorize the data by dates
        dates = {}

        for reading in self.readings:
            date = reading["date"]
            # Check if date exists in dict
            if date not in dates:
                dates[date] = []

            # Add blood glucose level to list
            dates[date].append(reading["level"])

        # Add data to self.daily_readings
        for date in dates:
            average_level = sum(dates[date])/len(dates[date])
            self.daily_readings.append({"date": date, "level": average_level})

    def get_all_readings(self) -> List[Dict[str, Union[str, str, float]]]:
        """
        Returns the full list of readings
        """

        return self.readings
    
    def get_number_of_readings(self, n: int) -> List[Dict[str, Union[str, str, float]]]:
        """
        Returns the n most recent readings

        Arguments:
            n: Number of readings to return
        """

        return self.readings[-n:]
    
    def get_readings_by_day(self, date: str) -> List[Dict[str, Union[str, str, float]]]:
        """
        Returns all readings with a certain date

        Arguments:
            date: The date to look for
        """

        # Make a list of every reading if and only if the reading's date is equal to the desired date
        date_readings = [reading for reading in self.readings if reading["date"] == date]
        return date_readings
    
    def get_all_daily_readings(self) -> List[Dict[str, Union[str, str, float]]]:
        """
        Returns the full list of daily readings
        """

        return self.daily_readings
    
    def get_average_level_by_day(self, date: str) -> float:
        """
        Returns the average dailyblood glucose level at a certain date

        Arguments:
            date: The date to look for
        """

        # Check if date exists
        for reading in self.daily_readings:
            if reading["date"] == date:
                return reading["level"]

        # Date doesn't exist
        return -1.0

# For testing
if __name__ == "__main__":
    glu = Glucose_Data("glucose_time_data.csv")

    # Readings
    print("Daily Readings:", glu.get_all_daily_readings(), "\n", "-"*20)
    print("Readings:", glu.get_all_readings(), "\n", "-"*20) 
    print("Last 5 Readings:", glu.get_number_of_readings(5), "\n", "-"*20)
    print("Average level of 9/30/2024:", glu.get_average_level_by_day("9/30/2024"), "\n", "-"*20)
    print("Readings of 9/30/2024:", glu.get_readings_by_day("9/30/2024"), "\n", "-"*20)