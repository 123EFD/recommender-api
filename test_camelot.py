import os
import sys
import camelot.io as camelot
import pandas as pd

# 1. PATH FIX: This must happen BEFORE importing camelot
gs_bin_path = r'C:\Program Files\gs\gs10.06.0\bin'
if gs_bin_path not in os.environ['PATH']:
    os.environ['PATH'] += os.pathsep + gs_bin_path

try:
    import camelot
    # read_pdf is exported from camelot.io
    from camelot.io import read_pdf
    print("✅ Camelot module loaded correctly.")
except ImportError:
    print("❌ Camelot not found. Run: pip install 'camelot-py[cv]'")
    sys.exit()

def test_extraction(pdf_path):
    print(f"Attempting extraction on: {pdf_path}")
    try:
        # flavor='lattice' targets PDFs with visible grid lines
        tables = read_pdf(pdf_path, pages='7', flavor='lattice')
        
        if len(tables) > 0:
            print(f"✅ SUCCESS! Found {len(tables)} table(s).")
            # Show the actual data to prove Ghostscript is working
            print(tables[0].df.head()) 
        else:
            print("❓ Ghostscript works, but no tables were detected on page 1.")
    except Exception as e:
        print(f"❌ EXTRACTION FAILED!")
        print(f"Error: {e}")

if __name__ == "__main__":
    target_pdf = 'FSKTM brochure.pdf' 
    if os.path.exists(target_pdf):
        test_extraction(target_pdf)
    else:
        print(f"❌ File not found: {target_pdf}. Put it in this folder!")