# Koncluí icon — generation prompts

Generated with ai-image-gen (gpt route), reference: Koru's idle concept (`design/koru/koru-coucou-01-idle.webp`).
The art is generated full-bleed; `build_icons.py` masks it into the macOS plate (824 px rounded square on a 1024 canvas)
and adds the drop shadow, so the plate geometry is exact and not left to the generator. Outputs are in `candidates/`;
B (warm plate) is the icon: the teal owl stands out on light and dark docks, A's dark plate fades into a dark dock and
C's sky plate is too close to Koru's teal.

## Shared character block

Koru, the cute round chubby owl from the reference image: soft-touch matte teal body (#3EA5B1, lighter #6CCAD5 on top),
two pointed feather tufts on top of the head, a lighter teal facial disc made of two joined circles that meet in a
sharp V between the eyes, huge round orange eyes (#FEA638) with big dark teal pupils (#164149) and one small white
highlight each, a small orange teardrop beak, a lighter teal belly patch. Same proportions and style as the reference.

## A — dark plate

macOS app icon artwork, square, FULL-BLEED: the background fills the whole canvas edge to edge, no rounded corners,
no border, no frame, no outer shadow, no text. Background: deep midnight teal-black gradient (#123038 at the top to
#0A1418 at the bottom) with a soft teal glow behind the character. {character}. Show the head and upper body big,
centered, filling about 82 % of the canvas width, the body running off the bottom edge. Soft 3D depth, gentle top
light, clean simple shapes, high contrast; it must stay readable as a 16 pixel icon.

## B — warm light plate

Same as A, background: soft warm gradient from cream (#FFF4E2) at the top to light apricot (#FFD49A) at the bottom.

## C — sky plate

Same as A, background: luminous gradient from light aqua-white (#E6FBFF) at the top to sky blue (#7CCBEA) at the bottom.
