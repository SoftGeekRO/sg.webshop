import subprocess
from django.core.management.base import BaseCommand
from django.core.management import call_command


class Command(BaseCommand):
    help = "Compile .po translation files and restart Gunicorn via Supervisor"

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE("🔤 Compiling translation files..."))
        try:
            call_command("compilemessages", verbosity=1)
            self.stdout.write(
                self.style.SUCCESS("✅ Translations compiled successfully.")
            )
        except Exception as e:
            self.stderr.write(self.style.ERROR(f"❌ Failed to compile messages: {e}"))
            return

        self.stdout.write(self.style.NOTICE("🔁 Restarting Gunicorn..."))
        try:
            result = subprocess.run(
                ["sudo", "supervisorctl", "restart", "webstore"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            self.stdout.write(
                self.style.SUCCESS(f"✅ Gunicorn restarted:\n{result.stdout}")
            )
        except subprocess.CalledProcessError as e:
            self.stderr.write(
                self.style.ERROR(f"❌ Error restarting Gunicorn:\n{e.stderr}")
            )
