"""Compatibility entry point for the free, attributed audio import pipeline.

The former oscillator-based soundtrack is retired. Use --fetch only when the
pinned source downloads are missing from outputs/audio-sources.
"""
from pathlib import Path
import runpy

if __name__ == '__main__':
    runpy.run_path(str(Path(__file__).with_name('import_free_audio.py')), run_name='__main__')
