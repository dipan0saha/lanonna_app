#!/usr/bin/env python3
"""Backward-compatible entry: runs full Maestro fixture provisioning."""

from provision_maestro_fixtures import cmd_all
import argparse


def main() -> None:
    cmd_all(argparse.Namespace())


if __name__ == "__main__":
    main()
