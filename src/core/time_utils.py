"""
Timezone-safe datetime utilities.

STRICT RULE: All timestamps MUST be UTC-aware.

This module provides utilities to ensure all datetime operations use
timezone-aware UTC timestamps, preventing comparison errors between
naive and aware datetimes.
"""

from datetime import datetime, timezone
from typing import Optional


def utc_now() -> datetime:
    """
    Get current UTC time as timezone-aware datetime.
    
    Returns:
        datetime: Current time in UTC with timezone info
    
    Example:
        >>> utc_now()
        datetime.datetime(2026, 1, 25, 8, 49, 11, 865844, tzinfo=datetime.timezone.utc)
    """
    return datetime.now(timezone.utc)


def parse_iso_timestamp(timestamp_str: str) -> datetime:
    """
    Parse ISO timestamp string safely, ensuring result is UTC-aware.
    
    Args:
        timestamp_str: ISO format timestamp (may or may not have timezone)
    
    Returns:
        datetime: UTC-aware datetime
    
    Raises:
        ValueError: If timestamp string is invalid
    
    Examples:
        >>> parse_iso_timestamp("2026-01-25T08:49:11.801515")
        datetime.datetime(2026, 1, 25, 8, 49, 11, 801515, tzinfo=datetime.timezone.utc)
        
        >>> parse_iso_timestamp("2026-01-25T08:49:11.865844+00:00")
        datetime.datetime(2026, 1, 25, 8, 49, 11, 865844, tzinfo=datetime.timezone.utc)
    """
    dt = datetime.fromisoformat(timestamp_str)
    
    # If naive (no timezone), assume UTC
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    
    # Convert to UTC if in different timezone
    return dt.astimezone(timezone.utc)


def to_iso_string(dt: datetime) -> str:
    """
    Convert datetime to ISO string with UTC timezone.
    
    Args:
        dt: datetime object (naive or aware)
    
    Returns:
        str: ISO format string with +00:00 timezone
    
    Example:
        >>> to_iso_string(utc_now())
        "2026-01-25T08:49:11.865844+00:00"
    """
    # If naive, assume UTC
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    
    # Convert to UTC and format
    return dt.astimezone(timezone.utc).isoformat()
