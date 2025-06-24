from markdown.extensions import Extension
from markdown.preprocessors import Preprocessor
import re


class YouTubeEmbedPreprocessor(Preprocessor):
    """
    A Markdown preprocessor to convert custom YouTube embed syntax into iframe HTML.

    It looks for lines in the markdown that match the pattern:
        @youtube(<url>[, width=<width>][, height=<height>])

    Example markdown usage:
        @youtube(https://www.youtube.com/watch?v=P4nv2O3i_kQ, width=800, height=450)

    This will be converted into:
        <iframe width="800" height="450" src="https://www.youtube.com/embed/P4nv2O3i_kQ"
                frameborder="0" allowfullscreen></iframe>

    If width or height are not specified, defaults to 560x315.
    """

    def run(self, lines):
        """
        Process each line of markdown input, replacing any YouTube embed syntax with iframe HTML.

        Args:
            lines (list of str): Lines of the markdown content.

        Returns:
            list of str: Processed lines with YouTube embed syntax replaced by iframe HTML.
        """
        new_lines = []
        # Regex to match @youtube(url, optional width=number, optional height=number)
        pattern = re.compile(
            r"""@youtube\(
                \s*(https?://[^\s,]+)          # Capture the YouTube URL
                (?:,\s*width=(\d+))?           # Optional width parameter (digits only)
                (?:,\s*height=(\d+))?          # Optional height parameter (digits only)
                \s*\)
            """,
            re.VERBOSE,
        )

        for line in lines:
            match = pattern.search(line)
            if match:
                url = match.group(1)
                width = match.group(2) or "560"  # Default width if not provided
                height = match.group(3) or "315"  # Default height if not provided

                video_id = None
                # Extract the YouTube video ID from URL formats
                if "youtube.com/watch?v=" in url:
                    video_id = url.split("v=")[1].split("&")[0]
                elif "youtu.be/" in url:
                    video_id = url.split("/")[-1]

                if video_id:
                    # Construct the iframe embed HTML
                    iframe = (
                        f'<iframe width="{width}" height="{height}" '
                        f'src="https://www.youtube.com/embed/{video_id}" '
                        f'frameborder="0" allowfullscreen></iframe>'
                    )
                    line = iframe  # Replace the markdown line with the iframe HTML
            new_lines.append(line)

        return new_lines


class YouTubeEmbedExtension(Extension):
    def extendMarkdown(self, md):
        md.preprocessors.register(YouTubeEmbedPreprocessor(md), "youtube_embed", 25)


def makeExtension(**kwargs):
    return YouTubeEmbedExtension(**kwargs)
