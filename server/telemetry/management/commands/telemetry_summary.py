"""Prints P6's counts over the stored telemetry events as JSON.

    python manage.py telemetry_summary [--since 2026-12-02T00:00:00+09:00]
"""

import json

from django.core.management.base import BaseCommand, CommandError
from django.utils.dateparse import parse_datetime

from telemetry.models import TelemetryEvent
from telemetry.summary import summarize


class Command(BaseCommand):
    help = "Counts the telemetry events by P6's rules."

    def add_arguments(self, parser):
        parser.add_argument("--since", help="only events at or after this ISO time")

    def handle(self, *args, since=None, **options):
        events = TelemetryEvent.objects.all()
        if since:
            at = parse_datetime(since)
            if at is None or at.tzinfo is None:
                raise CommandError("--since needs an ISO time with its offset")
            events = events.filter(ts__gte=at)
        self.stdout.write(json.dumps(summarize(events), ensure_ascii=False, indent=2))
