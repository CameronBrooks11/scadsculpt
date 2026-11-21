default:
    @just --list

# Render each sculpture: one solid, faces outward, on the bed, at its size
test:
    python3 tests/test_sculptures.py

# Render the README pictures into assets/
images:
    @mkdir -p assets
    openscad --camera=0,0,33,55,0,25,380 --imgsize=600,450 --colorscheme=Tomorrow -o assets/chiral-sonic-bloom.png chiral_sonic_bloom.scad
    openscad --camera=0,0,40,55,0,25,280 --imgsize=600,450 --colorscheme=Tomorrow -o assets/crystal-helix-knot.png crystal_helix_knot.scad
    openscad --camera=0,0,81,70,0,25,420 --imgsize=450,600 --colorscheme=Tomorrow -o assets/hyper-gargoyle.png hyper_gargoyle.scad
    openscad --camera=0,0,90,70,0,30,480 --imgsize=450,600 --colorscheme=Tomorrow -o assets/flame-plumes.png flame_plumes.scad

# Everything CI runs, bar the tests
check: fmt-check

# Format the .scad sources with topiary (.topiary/languages.ncl)
fmt:
    git ls-files -z '*.scad' | xargs -0 -r topiary format

# Check the .scad sources are formatted, without changing them
fmt-check:
    git ls-files -z '*.scad' | xargs -0 -r -n1 topiary format --check
