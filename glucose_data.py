import csv
from typing import List, Dict, Union
from datetime import datetime, timedelta

class GlucoseData():
    """Holds data and methods of adjusting and reading data"""

    def __init__(self, file_name: str) -> None:
        """Initializes using the data file for processing"""
        self.file = open(file_name, "r")
        self.reader = csv.reader(self.file)

        self.readings = []  # Contains data as {"date": date (str), "time": time, "level": level (float)}
        self.process_readings()

        # Save the data made so it doesn't need to be re-done
        self.saved_recent_readings = []
        self.saved_daily_readings = []
        self.saved_weekly_readings = []
        self.saved_monthly_readings = []

        # Generate data for today on launch
        current_date = datetime.now()
        formatted_date = current_date.strftime("%m/%d/%Y")

        self.get_readings_by_day(formatted_date)
        self.get_readings_by_week(formatted_date)
        self.get_readings_by_month(formatted_date)

        self.file.close()

    def process_readings(self) -> None:
        """Update self.readings to contain all the data from the data file"""
        
        # Skip headers
        next(self.reader)

        # Store each CSV row in the the dictionary
        for row in self.reader:
            data = {"date": row[0], "time": row[1], "level": float(row[2])}
            self.readings.append(data)

    def get_recent_readings(self, num_readings: int) -> List[Dict[str, Union[str, str, float]]]:
        """Return a certain amount of the most recent readings"""
        
        # Edge case: too many readings requested
        if num_readings > len(self.readings):
            self.saved_recent_readings = self.readings[:]
            return self.readings
        
        self.saved_recent_readings = self.readings[-num_readings][:]
        return self.readings[-num_readings]

    def get_all_readings(self) -> List[Dict[str, Union[str, str, float]]]:
        """Returns the full list of readings"""

        return self.readings[:]

    def get_readings_by_day(self, date: str) -> List[Dict[str, Union[str, str, float]]]:
        """Returns all readings for a specific date"""

        day_readings = [reading for reading in self.readings if reading["date"] == date]
        self.saved_daily_readings = day_readings[:]

        return day_readings

    def get_readings_by_week(self, end_date: str) -> List[Dict[str, Union[str, str, float]]]:
        """
        Return all readings for the 7 days leading up to and including the end date
        
        Arguments:
            end_date: The date at the end of the week
        """
        # Obtain bounds of the week
        end_date = datetime.strptime(end_date, "%m/%d/%Y")
        start_date = end_date - timedelta(days=6)  # Get the start date (7 days range)
        
        # Go through the readings and keep all within range
        weekly_readings = [
            reading for reading in self.readings
            if start_date <= datetime.strptime(reading["date"], "%m/%d/%Y") <= end_date
        ]

        self.saved_weekly_readings = weekly_readings[:]
        return weekly_readings

    def get_readings_by_month(self, provided_date: str) -> List[Dict[str, Union[str, str, float]]]:
        """
        Return all readings for the month of the provided date
        
        Arguments:
            provided_date: Date whose month should be used for the search
        """
        # Obtain bounds of the month
        provided_datetime = datetime.strptime(provided_date, "%m/%d/%Y")
        month_start = provided_datetime.replace(day=1)  # Start of the month
        next_month = (month_start + timedelta(days=32)).replace(day=1)  # Start of next month

        # Go through the readings and keep all within range
        monthly_readings = [
            reading for reading in self.readings
            if month_start <= datetime.strptime(reading["date"], "%m/%d/%Y") < next_month
        ]

        self.saved_monthly_readings = monthly_readings[:]
        return monthly_readings
    
    def get_saved_recent_readings(self) -> List[Dict[str, Union[str, str, float]]]:
        """ Return the most recently generated recent readings """

        return self.saved_recent_readings[:]
    
    def get_saved_daily_readings(self) -> List[Dict[str, Union[str, str, float]]]:
        """ Return the most recently generated daily readings """

        return self.saved_daily_readings[:]
    
    def get_saved_weekly_readings(self) -> List[Dict[str, Union[str, str, float]]]:
        """ Return the most recently generated weekly readings """

        return self.saved_weekly_readings[:]
    
    def get_saved_monthly_readings(self) -> List[Dict[str, Union[str, str, float]]]:
        """ Return the most recently generated monthly readings """

        return self.saved_monthly_readings[:]
