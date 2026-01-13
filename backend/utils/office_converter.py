"""
Office Document to PDF Converter
=================================

Converts Office documents (.docx, .xlsx, .pptx, .doc, .xls, .ppt) to PDF using LibreOffice.
Supports embedded images and maintains high-fidelity formatting.

Dependencies:
    - LibreOffice (installed as system package)

Usage:
    from utils.office_converter import convert_office_to_pdf

    # Convert Office file to PDF
    pdf_path = convert_office_to_pdf("/path/to/document.docx")

    # Or specify output path
    pdf_path = convert_office_to_pdf("/path/to/document.docx", "/path/to/output.pdf")
"""

import os
import subprocess
import tempfile
from pathlib import Path
from typing import Optional

from loguru import logger


# Supported Office file extensions
SUPPORTED_OFFICE_EXTENSIONS = {
    # Microsoft Office formats
    ".docx",  # Word
    ".xlsx",  # Excel
    ".pptx",  # PowerPoint
    ".doc",   # Legacy Word
    ".xls",   # Legacy Excel
    ".ppt",   # Legacy PowerPoint
    # OpenDocument formats
    ".odt",   # OpenDocument Text
    ".ods",   # OpenDocument Spreadsheet
    ".odp",   # OpenDocument Presentation
    # Other formats
    ".rtf",   # Rich Text Format
    ".html",  # HTML
    ".htm",   # HTML
}


def is_libreoffice_available() -> bool:
    """
    Check if LibreOffice is available on the system.

    Returns:
        True if LibreOffice is installed, False otherwise
    """
    try:
        result = subprocess.run(
            ["libreoffice", "--version"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def convert_office_to_pdf(
    input_file: str,
    output_file: Optional[str] = None,
    timeout: int = 300,
) -> str:
    """
    Convert Office documents to PDF using LibreOffice.

    This function uses LibreOffice in headless mode to convert Office documents
    to PDF format. It supports all common Office file formats including legacy
    formats (.doc, .xls, .ppt) and preserves embedded images.

    Args:
        input_file: Path to the Office document to convert
        output_file: Optional output PDF path. If not provided, will create
                     PDF in the same directory as input file
        timeout: Maximum time (seconds) to wait for conversion (default: 300)

    Returns:
        Path to the generated PDF file

    Raises:
        FileNotFoundError: If input file doesn't exist
        ValueError: If file format is not supported
        RuntimeError: If LibreOffice is not available or conversion fails

    Examples:
        >>> pdf_path = convert_office_to_pdf("document.docx")
        >>> print(pdf_path)
        /path/to/document.pdf

        >>> pdf_path = convert_office_to_pdf("spreadsheet.xlsx", "output.pdf")
        >>> print(pdf_path)
        output.pdf
    """
    # Validate input file
    input_path = Path(input_file)
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_file}")

    # Check file extension
    file_ext = input_path.suffix.lower()
    if file_ext not in SUPPORTED_OFFICE_EXTENSIONS:
        raise ValueError(
            f"Unsupported file format: {file_ext}. "
            f"Supported formats: {', '.join(sorted(SUPPORTED_OFFICE_EXTENSIONS))}"
        )

    # Check if LibreOffice is available
    if not is_libreoffice_available():
        raise RuntimeError(
            "LibreOffice is not available. Please install LibreOffice:\n"
            "  Ubuntu/Debian: sudo apt-get install libreoffice\n"
            "  CentOS/RHEL: sudo yum install libreoffice\n"
            "  macOS: brew install --cask libreoffice"
        )

    # Determine output file path
    if output_file:
        output_path = Path(output_file)
        output_dir = output_path.parent
        output_name = output_path.stem
    else:
        output_dir = input_path.parent
        output_name = input_path.stem

    # Create output directory if it doesn't exist
    output_dir.mkdir(parents=True, exist_ok=True)

    # Expected output PDF path (LibreOffice always uses .pdf extension)
    expected_pdf = output_dir / f"{input_path.stem}.pdf"

    try:
        logger.info(f"📄 Converting Office document to PDF: {input_file}")
        logger.info(f"   Output directory: {output_dir}")

        # Run LibreOffice conversion
        # --headless: Run without GUI
        # --convert-to pdf: Convert to PDF format
        # --outdir: Output directory
        cmd = [
            "libreoffice",
            "--headless",
            "--convert-to",
            "pdf",
            "--outdir",
            str(output_dir),
            str(input_path.absolute()),
        ]

        logger.debug(f"   Command: {' '.join(cmd)}")

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )

        # Check if conversion was successful
        if result.returncode != 0:
            error_msg = result.stderr.strip() if result.stderr else result.stdout.strip()
            raise RuntimeError(
                f"LibreOffice conversion failed with exit code {result.returncode}:\n{error_msg}"
            )

        # Verify output file was created
        if not expected_pdf.exists():
            raise RuntimeError(
                f"Conversion appeared successful but output file not found: {expected_pdf}"
            )

        # If user specified a different output filename, rename it
        if output_file and Path(output_file).name != expected_pdf.name:
            final_path = Path(output_file)
            expected_pdf.rename(final_path)
            logger.info(f"✅ Converted to PDF: {final_path}")
            return str(final_path)

        logger.info(f"✅ Converted to PDF: {expected_pdf}")
        return str(expected_pdf)

    except subprocess.TimeoutExpired:
        raise RuntimeError(
            f"Conversion timeout after {timeout} seconds. "
            f"Try increasing the timeout for large files."
        )
    except Exception as e:
        logger.error(f"❌ Failed to convert {input_file} to PDF: {e}")
        raise


def convert_office_to_pdf_temp(
    input_file: str,
    timeout: int = 300,
) -> str:
    """
    Convert Office document to PDF in a temporary directory.

    This is useful for intermediate conversions where you don't need to
    specify the output location.

    Args:
        input_file: Path to the Office document to convert
        timeout: Maximum time (seconds) to wait for conversion (default: 300)

    Returns:
        Path to the generated PDF file in a temporary directory

    Raises:
        Same as convert_office_to_pdf()

    Note:
        The caller is responsible for cleaning up the temporary file.
    """
    # Create temporary directory
    temp_dir = Path(tempfile.mkdtemp(prefix="office2pdf_"))

    # Generate output filename
    input_path = Path(input_file)
    output_file = temp_dir / f"{input_path.stem}.pdf"

    # Convert
    return convert_office_to_pdf(input_file, str(output_file), timeout)


# Test function for development
def _test_conversion():
    """Test the conversion with sample files (for development only)."""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python office_converter.py <input_file> [output_file]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        pdf_path = convert_office_to_pdf(input_file, output_file)
        print(f"✅ Success! PDF created at: {pdf_path}")
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    _test_conversion()
