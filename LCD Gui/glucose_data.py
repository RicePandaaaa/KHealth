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
        
        self.saved_recent_readings = self.readings[-num_readings][:]  # Store recent readings
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
        """Return all readings for the 7 days leading up to and including the end date"""
        end_date = datetime.strptime(end_date, "%m/%d/%Y")
        start_date = end_date - timedelta(days=6)  # Get the start date (7 days range)

        weekly_readings = [
            reading for reading in self.readings
            if start_date <= datetime.strptime(reading["date"], "%m/%d/%Y") <= end_date
        ]

        self.saved_weekly_readings = weekly_readings[:]
        return weekly_readings

    def get_readings_by_month(self, provided_date: str) -> List[Dict[str, Union[str, str, float]]]:
        """Return all readings for the month of the provided date"""
        provided_datetime = datetime.strptime(provided_date, "%m/%d/%Y")
        month_start = provided_datetime.replace(day=1)  # Start of the month
        next_month = (month_start + timedelta(days=32)).replace(day=1)  # Start of next month

        monthly_readings = [
            reading for reading in self.readings
            if month_start <= datetime.strptime(reading["date"], "%m/%d/%Y") < next_month
        ]

        self.saved_monthly_readings = monthly_readings[:]
        return monthly_readings

    def get_average_previous_day(self, current_date: str) -> Union[float, None]:
        """
        Returns the average blood glucose of the day before the current date, or None if no data is available.
        
        Arguments:
            current_date: Today's date in string format mm/dd/yyyy
        """
        current_datetime = datetime.strptime(current_date, "%m/%d/%Y")
        previous_day = current_datetime - timedelta(days=1)  # Get the previous day
        previous_day_str = previous_day.strftime("%m/%d/%Y")

        readings = self.get_readings_by_day(previous_day_str)
        
        if not readings:
            return None  # No data for the previous day

        # Calculate the average blood glucose level
        average_glucose = sum([reading['level'] for reading in readings]) / len(readings)
        return average_glucose

    def get_average_previous_week(self, current_date: str) -> Union[float, None]:
        """
        Returns the average blood glucose of the full week before the start of this week.
        The current date marks the end of the current week.

        Arguments:
            current_date: Today's date in string format mm/dd/yyyy
        """
        # Calculate bounds of this week
        current_datetime = datetime.strptime(current_date, "%m/%d/%Y")
        start_of_current_week = current_datetime - timedelta(days=6)  

        # then use those bounds to calculate bounds of last week
        end_of_previous_week = start_of_current_week - timedelta(days=1)  
        start_of_previous_week = end_of_previous_week - timedelta(days=6)  

        # Filter readings that fall within the previous week
        previous_week_readings = [
            reading for reading in self.readings
            if start_of_previous_week <= datetime.strptime(reading["date"], "%m/%d/%Y") <= end_of_previous_week
        ]

        if not previous_week_readings:
            return None  # No data for the previous week

        # Calculate the average blood glucose level
        average_glucose = sum([reading['level'] for reading in previous_week_readings]) / len(previous_week_readings)
        return average_glucose
    
    def get_average_previous_month(self, current_date: str) -> Union[float, None]:
        """
        Returns the average blood glucose of the previous month based on the current date.
        """
        current_datetime = datetime.strptime(current_date, "%m/%d/%Y")
        
        # Get the start of the current month and the previous month
        start_of_current_month = current_datetime.replace(day=1)
        end_of_previous_month = start_of_current_month - timedelta(days=1)  # Last day of the previous month
        start_of_previous_month = end_of_previous_month.replace(day=1)  # First day of the previous month

        # Filter readings that fall within the previous month
        previous_month_readings = [
            reading for reading in self.readings
            if start_of_previous_month <= datetime.strptime(reading["date"], "%m/%d/%Y") <= end_of_previous_month
        ]

        if not previous_month_readings:
            return None  # No data for the previous month

        # Calculate the average blood glucose level
        average_glucose = sum([reading['level'] for reading in previous_month_readings]) / len(previous_month_readings)
        return average_glucose
