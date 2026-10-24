#!/usr/bin/env python3
"""Compatibility entry point: build the complete handmade clay catalog with Blender."""
import pathlib, subprocess
if __name__ == '__main__':
    subprocess.run(['blender','-b','-t','2','--python-exit-code','1','--python',str(pathlib.Path(__file__).with_name('build_crafted_models.py')),'--','--style','bright_clay'],check=True)
