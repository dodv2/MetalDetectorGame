# LEGACY (Update 16). The live map is map/Map.rbxmx (Update 17 Pier + beach scenery) - do NOT
# regenerate it with this script, it would bring back the Update 16 map.
# Generates map/Map.model.json (Rojo model) - the whole world: 7 zones, hub town, shop street with 8 plots.
import json, math, random
random.seed(7)

def rgb(r, g, b): return [r/255, g/255, b/255]

def matmul(a, b): return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def rx(t): c,s=math.cos(t),math.sin(t); return [[1,0,0],[0,c,-s],[0,s,c]]
def ry(t): c,s=math.cos(t),math.sin(t); return [[c,0,s],[0,1,0],[-s,0,c]]
def rz(t): c,s=math.cos(t),math.sin(t); return [[c,-s,0],[s,c,0],[0,0,1]]
def angles(x=0, y=0, z=0):  # CFrame.Angles(x, y, z) = Rx * Ry * Rz  (degrees)
    return matmul(matmul(rx(math.radians(x)), ry(math.radians(y))), rz(math.radians(z)))
IDENT = [[1,0,0],[0,1,0],[0,0,1]]
def norm(v): l=math.sqrt(sum(c*c for c in v)); return [c/l for c in v]
def cross(a,b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
def look_dir(d):  # rotation whose -Z points along d (horizontal), like CFrame.lookAt
    z = norm([-d[0], -d[1], -d[2]]); x = norm(cross([0,1,0], z)); y = cross(z, x)
    return [[x[0],y[0],z[0]],[x[1],y[1],z[1]],[x[2],y[2],z[2]]]
def apply(R, v): return [sum(R[i][k]*v[k] for k in range(3)) for i in range(3)]

def cf(pos, rot=IDENT): return {"CFrame": {"position": [round(c, 4) for c in pos], "orientation": [[round(c, 6) for c in row] for row in rot]}}

def part(name, size, pos, color, material="SmoothPlastic", rot=IDENT, shape=None, cls="Part", transparency=0, collide=True, query=True, shadow=True, attrs=None, children=None, extra=None):
    props = {"Anchored": True, "Size": [round(s, 4) for s in size], "CFrame": cf(pos, rot), "Color": color, "Material": material,
             "TopSurface": "Smooth", "BottomSurface": "Smooth"}
    if shape: props["Shape"] = shape
    if transparency: props["Transparency"] = transparency
    if not collide: props["CanCollide"] = False
    if not query: props["CanQuery"] = False; props["CanTouch"] = False
    if not shadow: props["CastShadow"] = False
    if extra: props.update(extra)
    node = {"name": name, "className": cls, "properties": props}
    if attrs: node["attributes"] = attrs
    if children: node["children"] = children
    return node

def sphere_mesh(scale=None):
    props = {"MeshType": "Sphere"}
    if scale: props["Scale"] = scale
    return {"name": "Mesh", "className": "SpecialMesh", "properties": props}

def ellip(name, size, pos, color, material="SmoothPlastic", rot=IDENT, **kw):
    """Smooth ellipsoid: a block part wearing a sphere mesh."""
    kids = kw.pop("children", None) or []
    return part(name, size, pos, color, material, rot=rot, children=[sphere_mesh()] + kids, **kw)

def folder(name, children, cls="Folder", attrs=None):
    node = {"name": name, "className": cls, "children": children}
    if attrs: node["attributes"] = attrs
    return node

def udim2(xs, xo, ys, yo): return {"UDim2": [[xs, xo], [ys, yo]]}

def sign_gui(text, color=rgb(255,255,255), face="Front", ppu=20, font="FredokaOne", bg=None):
    label_props = {"Text": text, "TextScaled": True, "Font": font, "TextColor3": color, "BackgroundTransparency": 1 if bg is None else 0,
                   "Size": udim2(0.94, 0, 0.86, 0), "Position": udim2(0.03, 0, 0.07, 0), "TextStrokeTransparency": 0.4}
    if bg is not None: label_props["BackgroundColor3"] = bg
    return {"name": "SignGui", "className": "SurfaceGui", "properties": {"Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": ppu, "LightInfluence": 0},
            "children": [{"name": "Label", "className": "TextLabel", "properties": label_props}]}

def prompt(action, obj, open_ui, tab=None):
    attrs = {"OpenUI": open_ui}
    if tab: attrs["OpenTab"] = tab
    return {"name": "Prompt", "className": "ProximityPrompt", "properties": {"ActionText": action, "ObjectText": obj, "HoldDuration": 0,
            "MaxActivationDistance": 14, "RequiresLineOfSight": False}, "attributes": attrs}

# ---------------------------------------------------------------- decorations
def palm(name, x, z, h=18, y0=0, lean=8):
    kids = []
    segs = 6; ang = random.uniform(0, 360)
    dx, dz = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    top = [x, y0, z]
    for i in range(segs):
        t0 = i / segs; seg_h = h / segs
        off = (t0 ** 2) * lean
        p = [x + dx*off, y0 + seg_h*(i+0.5), z + dz*off]
        kids.append(part(f"Trunk{i}", [seg_h+0.3, 1.5 - i*0.08, 1.5 - i*0.08], p, rgb(140, 100, 62), "Wood", rot=angles(0, 0, 90), shape="Cylinder"))
        # ringed bark: a slightly fatter, darker band where each leaf once grew
        ring_p = [x + dx*off, y0 + seg_h*(i+1), z + dz*off]
        kids.append(part(f"TrunkRing{i}", [0.35, 1.62 - i*0.08, 1.62 - i*0.08], ring_p, rgb(112, 80, 50), "Wood", rot=angles(0, 0, 90), shape="Cylinder", collide=False))
        top = [x + dx*((1)**2)*lean, y0 + h, z + dz*lean]
    for k in range(7):
        a = k * (360 / 7) + random.uniform(-10, 10)
        shade = rgb(56, 160, 72) if k % 2 == 0 else rgb(70, 178, 84)
        # inner half rises a little, outer half droops: a soft arching frond
        R1 = matmul(angles(0, a, 0), angles(12, 0, 0))
        o1 = apply(angles(0, a, 0), [0, 0, -2.6])
        kids.append(ellip(f"Leaf{k}", [2.4, 0.35, 5.6], [top[0]+o1[0], top[1]+0.2, top[2]+o1[2]], shade, "Grass", rot=R1, collide=False, shadow=True))
        R2 = matmul(angles(0, a, 0), angles(-38, 0, 0))
        o2 = apply(angles(0, a, 0), [0, 0, -6.6])
        kids.append(ellip(f"LeafTip{k}", [2.0, 0.3, 5.0], [top[0]+o2[0], top[1]-1.0, top[2]+o2[2]], shade, "Grass", rot=R2, collide=False))
        # pale midrib down the frond
        kids.append(part(f"Rib{k}", [0.18, 0.18, 9.6], [top[0]+apply(angles(0, a, 0), [0, 0, -4.4])[0], top[1]-0.25, top[2]+apply(angles(0, a, 0), [0, 0, -4.4])[2]],
                         rgb(150, 170, 90), "Wood", rot=matmul(angles(0, a, 0), angles(-12, 0, 0)), collide=False, shadow=False))
    kids.append(ellip("Crown", [2.2, 1.4, 2.2], [top[0], top[1], top[2]], rgb(70, 130, 60), "Grass"))
    for c in range(3):
        a = math.radians(c * 120 + 30)
        kids.append(part(f"Coconut{c}", [1.1, 1.1, 1.1], [top[0] + math.cos(a)*0.7, top[1]-0.9, top[2] + math.sin(a)*0.7], rgb(110, 76, 40), shape="Ball"))
    return folder(name, kids, "Model")

def rock(name, x, z, s, color=rgb(130, 128, 122), material="Slate", y0=0):
    # becomes smooth Terrain rock at runtime (EnvironmentService)
    return part(name, [s*random.uniform(0.9,1.4), s*random.uniform(0.6,1.0), s*random.uniform(0.9,1.3)], [x, y0 + s*0.25, z], color, material,
                rot=angles(random.uniform(-15,15), random.uniform(0,360), random.uniform(-15,15)), attrs={"TerrainMaterial": "Rock"})

def umbrella(name, x, z, color):
    return folder(name, [
        part("Pole", [9, 0.4, 0.4], [x, 4.5, z], rgb(240, 240, 240), rot=angles(0, 0, 90), shape="Cylinder"),
        ellip("Canopy", [10.5, 2.8, 10.5], [x, 9.2, z], color, "Fabric", collide=False),
        part("CanopyRim", [0.35, 10.2, 10.2], [x, 8.9, z], [min(1, c + 0.3) for c in color], "Fabric", rot=angles(0, 0, 90), shape="Cylinder", collide=False),
        part("Finial", [0.7, 0.7, 0.7], [x, 10.7, z], rgb(255, 255, 255), shape="Ball", collide=False),
        part("Towel", [3.5, 0.1, 7], [x + 4, 0.05, z + 1], [min(1, c + 0.25) for c in color], "Fabric"),
    ], "Model")

def sign(name, pos, size, text, facing, color=rgb(120, 80, 50), text_color=rgb(255, 240, 200), post=True):
    R = look_dir(facing)
    kids = [part("Board", size, pos, color, "WoodPlanks", rot=R, children=[sign_gui(text, text_color)])]
    for nm, dy in (("TrimTop", size[1] / 2), ("TrimBottom", -size[1] / 2)):
        p = apply(R, [0, dy, 0])
        kids.append(part(nm, [size[0] + 0.4, size[2] + 0.3, size[2] + 0.3], [pos[0]+p[0], pos[1]+p[1], pos[2]+p[2]], rgb(90, 60, 38), "Wood", rot=R, shape="Cylinder"))
    for nm, dx in (("CapL", -(size[0] / 2 + 0.2)), ("CapR", size[0] / 2 + 0.2)):
        for dy in (size[1] / 2, -size[1] / 2):
            p = apply(R, [dx, dy, 0])
            kids.append(part(nm, [1, 1, 1], [pos[0]+p[0], pos[1]+p[1], pos[2]+p[2]], rgb(255, 205, 90), "Metal", shape="Ball", collide=False))
    if post:
        kids.append(part("Post", [pos[1], 0.9, 0.9], [pos[0], pos[1]/2, pos[2]], rgb(100, 70, 45), "Wood", rot=angles(0, 0, 90), shape="Cylinder"))
        kids.append(part("PostFoot", [0.5, 1.6, 1.6], [pos[0], 0.25, pos[2]], rgb(90, 60, 38), "Wood", rot=angles(0, 0, 90), shape="Cylinder"))
    return folder(name, kids, "Model")

def column(name, x, z, h, broken=False, color=rgb(232, 226, 210)):
    kids = [part("Base", [0.8, 4.4, 4.4], [x, 0.4, z], color, "Marble", rot=angles(0, 0, 90), shape="Cylinder"),
            part("BaseRing", [0.5, 3.4, 3.4], [x, 1.05, z], color, "Marble", rot=angles(0, 0, 90), shape="Cylinder"),
            part("Shaft", [h, 2.6, 2.6], [x, 1 + h/2, z], color, "Marble", rot=angles(0, 0, 90), shape="Cylinder")]
    if not broken:
        kids.append(part("Neck", [0.4, 3.2, 3.2], [x, 0.9 + h, z], color, "Marble", rot=angles(0, 0, 90), shape="Cylinder"))
        kids.append(part("Capital", [0.9, 4.2, 4.2], [x, 1.5 + h, z], color, "Marble", rot=angles(0, 0, 90), shape="Cylinder"))
    else:
        kids.append(ellip("Chip", [2.4, 0.8, 2.4], [x + 0.4, 1 + h, z], color, "Marble", rot=angles(12, 30, -8)))
    return folder(name, kids, "Model")

class Frame:
    """Local building frame: local -Z = the shop's front (customer side)."""
    def __init__(self, center, yaw):
        self.c = center; self.R = angles(0, yaw, 0)
    def p(self, x, y, z):
        v = apply(self.R, [x, y, z]); return [self.c[0] + v[0], self.c[1] + v[1], self.c[2] + v[2]]
    def r(self, local=IDENT):
        return matmul(self.R, local)
    def shift(self, dx):
        f = Frame(self.p(dx, 0, 0), 0); f.R = self.R; return f

def fpart(F, name, size, lpos, color, material="SmoothPlastic", lrot=IDENT, **kw):
    return part(name, size, F.p(*lpos), color, material, rot=F.r(lrot), **kw)

def CYL_Y(): return angles(0, 0, 90)
def CYL_Z(): return angles(0, 90, 0)

# ---------------------------------------------------------------- coastal vegetation + props (Update 16)
GRASS_GREENS = [rgb(120, 150, 70), rgb(146, 162, 84), rgb(104, 140, 66), rgb(170, 166, 96)]

def dune_grass(name, x, z, y0=0, dry=False):
    """A clump of marram grass: tall, thin blades leaning out in the wind."""
    kids = []
    n = random.randint(6, 9)
    for i in range(n):
        a = random.uniform(0, 360); lean = random.uniform(8, 28); h = random.uniform(2.0, 3.6)
        col = rgb(196, 176, 112) if dry else random.choice(GRASS_GREENS)
        R = matmul(angles(0, a, 0), angles(lean, 0, 0))
        off = apply(R, [0, h / 2, 0])
        kids.append(part(f"Blade{i}", [0.14, h, 0.42], [x + off[0] + random.uniform(-0.4, 0.4), y0 + off[1], z + off[2] + random.uniform(-0.4, 0.4)],
                         col, "Grass", rot=R, collide=False, shadow=True))
    kids.append(ellip("Base", [2.2, 0.6, 2.2], [x, y0 + 0.1, z], rgb(150, 140, 90) if dry else rgb(110, 130, 70), "Grass", collide=False))
    return folder(name, kids, "Model")

def sea_grape(name, x, z, y0=0):
    """Sea grape bush: rounded clumps with big round leaves and little purple grape bunches."""
    kids = []
    for i in range(4):
        a = math.radians(i * 90 + random.uniform(-20, 20)); r = random.uniform(0.8, 1.6)
        s = random.uniform(2.6, 3.6)
        kids.append(ellip(f"Clump{i}", [s, s * 0.8, s], [x + math.cos(a) * r, y0 + s * 0.35, z + math.sin(a) * r], rgb(64, 120, 58), "Grass", collide=i == 0))
    for i in range(6):
        a = math.radians(i * 60 + random.uniform(-15, 15))
        kids.append(part(f"Leaf{i}", [0.12, 1.4, 1.4], [x + math.cos(a) * 2.0, y0 + 2.0 + random.uniform(-0.3, 0.6), z + math.sin(a) * 2.0],
                         rgb(84, 140, 66), "Grass", rot=matmul(angles(0, -math.degrees(a), 0), angles(0, 0, 60)), shape="Cylinder", collide=False))
    for i in range(3):
        kids.append(part(f"Grapes{i}", [0.45, 0.45, 0.45], [x + random.uniform(-1.4, 1.4), y0 + 1.6, z + random.uniform(-1.4, 1.4)], rgb(110, 50, 110), "SmoothPlastic", shape="Ball", collide=False))
    return folder(name, kids, "Model")

def coastal_pine(name, x, z, h=16, y0=0):
    """A wind-swept coastal pine: leaning trunk and flat, layered tiers of needles."""
    kids = []
    lean = random.uniform(6, 14); yaw = random.uniform(0, 360)
    R = matmul(angles(0, yaw, 0), angles(0, 0, lean))
    tip = apply(R, [0, h, 0])
    kids.append(part("Trunk", [h, 1.3, 1.3], [x + tip[0] / 2, y0 + tip[1] / 2, z + tip[2] / 2], rgb(110, 82, 60), "Wood", rot=matmul(R, angles(0, 0, 90)), shape="Cylinder"))
    for i in range(4):
        t = 0.45 + i * 0.17
        c = apply(R, [0, h * t, 0])
        w = 10 - i * 2.2
        drift = apply(angles(0, yaw, 0), [w * 0.12, 0, 0])
        kids.append(ellip(f"Tier{i}", [w, 1.8, w * 0.85], [x + c[0] + drift[0], y0 + c[1], z + c[2] + drift[2]],
                          rgb(48, 96, 60) if i % 2 == 0 else rgb(58, 110, 66), "Grass", collide=False))
    return folder(name, kids, "Model")

def hibiscus(name, x, z, y0=0):
    """Flowering tropical bush."""
    kids = [ellip("Bush", [4.2, 3.0, 4.0], [x, y0 + 1.3, z], rgb(52, 130, 64), "Grass"),
            ellip("Bush2", [3.0, 2.4, 3.2], [x + 1.4, y0 + 1.6, z - 0.8], rgb(66, 146, 70), "Grass", collide=False)]
    for i in range(7):
        a = math.radians(i * 51 + random.uniform(-10, 10))
        fx, fz = x + math.cos(a) * 1.9, z + math.sin(a) * 1.7
        col = random.choice([rgb(235, 50, 80), rgb(255, 110, 150), rgb(255, 170, 60)])
        kids.append(part(f"Flower{i}", [0.8, 0.8, 0.8], [fx, y0 + 1.8 + random.uniform(-0.4, 0.8), fz], col, "SmoothPlastic", shape="Ball", collide=False))
        kids.append(part(f"Stamen{i}", [0.3, 0.3, 0.3], [fx + math.cos(a) * 0.35, y0 + 2.0 + random.uniform(-0.2, 0.6), fz + math.sin(a) * 0.35], rgb(255, 230, 90), "Neon", shape="Ball", collide=False, shadow=False))
    return folder(name, kids, "Model")

def driftwood(name, x, z, y0=0):
    """Bleached, weathered driftwood half sunk in the sand."""
    a = random.uniform(0, 180); L = random.uniform(5, 9)
    kids = [part("Log", [L, 0.9, 0.9], [x, y0 + 0.25, z], rgb(176, 164, 146), "Wood", rot=angles(0, a, random.uniform(-6, 6)), shape="Cylinder")]
    b = apply(angles(0, a, 0), [L * 0.25, 0, 0])
    kids.append(part("Branch", [2.6, 0.45, 0.45], [x + b[0], y0 + 0.7, z + b[2]], rgb(166, 154, 136), "Wood", rot=angles(0, a + 50, 30), shape="Cylinder", collide=False))
    kids.append(part("Knot", [1.0, 1.0, 1.0], [x - b[0], y0 + 0.3, z - b[2]], rgb(150, 138, 120), "Wood", shape="Ball", collide=False))
    return folder(name, kids, "Model")

def beach_flag(name, x, z, colors=(rgb(230, 50, 40), rgb(255, 210, 40))):
    """Red-over-yellow lifeguard flag on a pole."""
    return folder(name, [
        part("Pole", [7, 0.3, 0.3], [x, 3.5, z], rgb(235, 235, 235), "Metal", rot=angles(0, 0, 90), shape="Cylinder"),
        part("Top", [0.08, 1.0, 2.0], [x, 6.4, z - 1.05], colors[0], "Fabric", collide=False),
        part("Bottom", [0.08, 1.0, 2.0], [x, 5.4, z - 1.05], colors[1], "Fabric", collide=False),
        part("Cap", [0.4, 0.4, 0.4], [x, 7.05, z], rgb(255, 255, 255), "SmoothPlastic", shape="Ball", collide=False),
    ], "Model")

def sand_fence(name, x0, z, x1, y0=0):
    """Weathered slatted sand fence with two wires, a bit wonky."""
    kids = []
    n = int(abs(x1 - x0) / 1.1)
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / max(n, 1)
        h = random.uniform(2.6, 3.2)
        kids.append(part(f"Slat{i}", [0.35, h, 0.12], [x, y0 + h / 2 - 0.3, z + random.uniform(-0.1, 0.1)], rgb(170, 150, 120), "WoodPlanks",
                         rot=angles(0, 0, random.uniform(-6, 6)), collide=False))
    for wy in (0.8, 2.1):
        kids.append(part(f"Wire{wy}", [abs(x1 - x0), 0.06, 0.06], [(x0 + x1) / 2, y0 + wy, z], rgb(90, 90, 95), "Metal", collide=False, shadow=False))
    for i, x in enumerate((x0, x1)):
        kids.append(part(f"Post{i}", [4.0, 0.5, 0.5], [x, y0 + 1.6, z], rgb(120, 100, 76), "Wood", rot=angles(0, 0, 90), shape="Cylinder"))
    return folder(name, kids, "Model")

def lifeguard_hut(x, z):
    """A weathered timber lifeguard / coast guard hut on stilts, facing the sea (-Z)."""
    F = Frame([x, 0, z], 0)
    wood, white, red, trim = rgb(156, 140, 118), rgb(234, 230, 220), rgb(196, 58, 50), rgb(120, 104, 86)
    deck_y = 5.5
    kids = []
    for sx in (-3.2, 3.2):
        for sz in (-3.6, 2.8):
            kids.append(fpart(F, "Stilt", [0.8, deck_y, 0.8], (sx, deck_y / 2, sz), wood, "WoodPlanks"))
        kids.append(fpart(F, "Brace", [0.3, 5.6, 0.3], (sx, 2.8, -0.4), trim, "Wood", lrot=angles(42, 0, 0), collide=False))
        kids.append(fpart(F, "Brace", [0.3, 5.6, 0.3], (sx, 2.8, -0.4), trim, "Wood", lrot=angles(-42, 0, 0), collide=False))
    kids.append(fpart(F, "Deck", [8.8, 0.5, 8.8], (0, deck_y - 0.25, -0.4), rgb(172, 152, 124), "WoodPlanks"))
    # porch railing (front + sides)
    for i, px in enumerate((-4.2, -1.4, 1.4, 4.2)):
        kids.append(fpart(F, f"RailPost{i}", [0.3, 2.0, 0.3], (px, deck_y + 1.0, -4.6), white, "Wood"))
    kids.append(fpart(F, "RailTop", [8.8, 0.22, 0.3], (0, deck_y + 2.0, -4.6), white, "Wood"))
    kids.append(fpart(F, "RailMid", [8.8, 0.16, 0.2], (0, deck_y + 1.1, -4.6), white, "Wood"))
    for sx in (-4.25, 4.25):
        kids.append(fpart(F, "SideRail", [0.3, 0.22, 2.6], (sx, deck_y + 2.0, -3.4), white, "Wood"))
    # stairs down the right side, towards the sea
    for i in range(6):
        kids.append(fpart(F, f"Step{i}", [2.2, 0.28, 0.95], (5.6, deck_y - 0.9 - i * 0.85, 1.6 - i * 0.95), wood, "WoodPlanks"))
    for sx in (4.5, 6.7):
        kids.append(fpart(F, "Stringer", [0.25, 0.6, 7.6], (sx, 2.7, -0.9), trim, "Wood", lrot=angles(-41, 0, 0), collide=False))
    # cabin: white plank walls with red corner trim
    cy = deck_y + 2.3
    kids.append(fpart(F, "BackWall", [7.6, 4.6, 0.3], (0, cy, 3.1), white, "WoodPlanks"))
    for sx in (-3.65, 3.65):
        kids.append(fpart(F, "SideWall", [0.3, 4.6, 5.4], (sx, cy, 0.55), white, "WoodPlanks"))
        kids.append(fpart(F, "SideWindow", [0.12, 1.6, 2.0], (sx * 1.03, cy + 0.4, 0.6), rgb(150, 200, 220), "Glass", transparency=0.45))
        kids.append(fpart(F, "SideWindowFrame", [0.18, 1.9, 0.18], (sx * 1.04, cy + 0.4, 0.6), white, "Wood", collide=False))
    kids.append(fpart(F, "FrontLow", [7.6, 1.6, 0.3], (0, deck_y + 0.8, -2.0), white, "WoodPlanks"))
    kids.append(fpart(F, "FrontHeader", [7.6, 0.8, 0.3], (0, deck_y + 4.2, -2.0), white, "WoodPlanks"))
    kids.append(fpart(F, "Window", [6.8, 2.2, 0.1], (0, deck_y + 2.7, -2.0), rgb(150, 200, 220), "Glass", transparency=0.5))
    for mx in (-3.5, -1.15, 1.15, 3.5):
        kids.append(fpart(F, "Mullion", [0.22, 2.3, 0.22], (mx, deck_y + 2.7, -2.05), white, "Wood"))
    kids.append(fpart(F, "Sill", [7.8, 0.2, 0.7], (0, deck_y + 1.6, -2.3), trim, "Wood"))
    for sx in (-3.8, 3.8):
        for sz in (-2.1, 3.2):
            kids.append(fpart(F, "Corner", [4.8, 0.36, 0.36], (sx, cy, sz), red, "Wood", lrot=CYL_Y(), shape="Cylinder"))
    kids.append(fpart(F, "Door", [0.14, 3.4, 1.7], (3.82, deck_y + 1.7, 2.0), red, "WoodPlanks"))
    kids.append(fpart(F, "DoorKnob", [0.25, 0.25, 0.25], (3.95, deck_y + 1.7, 1.4), rgb(255, 205, 90), "Metal", shape="Ball", collide=False))
    # pitched red roof with overhang and a ridge cap
    for side in (-1, 1):
        kids.append(fpart(F, "Roof", [4.9, 0.35, 7.6], (side * 2.2, deck_y + 5.4, 0.55), red, "WoodPlanks", lrot=angles(0, 0, -side * 22)))
    kids.append(fpart(F, "Ridge", [7.8, 0.5, 0.5], (0, deck_y + 6.3, 0.55), white, "Wood", lrot=CYL_Z(), shape="Cylinder"))
    kids.append(fpart(F, "Gable", [7.6, 1.6, 0.25], (0, deck_y + 5.2, -2.95), white, "WoodPlanks", collide=False))
    # signage
    kids.append(fpart(F, "Sign", [6.4, 1.4, 0.25], (0, deck_y + 4.9, -3.15), red, "WoodPlanks", children=[sign_gui("LIFEGUARD", rgb(255, 255, 255), ppu=30)]))
    kids.append(fpart(F, "Notice", [3.4, 2.2, 0.2], (-4.6, 2.6, -4.05), rgb(255, 240, 200), "SmoothPlastic",
                      children=[sign_gui("SWIM BETWEEN\nTHE FLAGS 🚩", rgb(170, 40, 30), ppu=26)]))
    kids.append(fpart(F, "NoticePost", [2.0, 0.3, 0.3], (-4.6, 1.0, -4.0), trim, "Wood", lrot=CYL_Y(), shape="Cylinder"))
    # flag on the roof
    kids.append(fpart(F, "FlagPole", [4.0, 0.2, 0.2], (-3.0, deck_y + 7.6, 2.4), rgb(230, 230, 230), "Metal", lrot=CYL_Y(), shape="Cylinder"))
    kids.append(fpart(F, "FlagRed", [0.06, 0.8, 1.8], (-3.0, deck_y + 9.1, 1.5), rgb(230, 50, 40), "Fabric", collide=False))
    kids.append(fpart(F, "FlagYellow", [0.06, 0.8, 1.8], (-3.0, deck_y + 8.3, 1.5), rgb(255, 210, 40), "Fabric", collide=False))
    # rescue equipment: ring buoy on the wall, a rescue board leaning on a stilt, a rescue tube on the rail,
    # a first-aid box and binoculars on the sill
    for i in range(12):
        a = i / 12 * math.pi * 2
        kids.append(fpart(F, f"Buoy{i}", [0.55, 0.32, 0.32], (-2.6 + math.cos(a) * 0.7, deck_y + 1.0 + math.sin(a) * 0.7, -2.25),
                          rgb(255, 120, 40) if i % 3 else rgb(255, 255, 255), "SmoothPlastic", lrot=angles(0, 0, math.degrees(a) + 90), shape="Cylinder", collide=False))
    kids.append(ellip("RescueBoard", [0.3, 7.6, 1.9], F.p(-4.3, 3.6, -3.3), red, "SmoothPlastic", rot=F.r(angles(-12, 0, 8))))
    kids.append(fpart(F, "BoardCrossV", [0.32, 1.6, 0.35], (-4.3, 4.4, -3.4), rgb(255, 255, 255), "SmoothPlastic", lrot=angles(-12, 0, 8), collide=False))
    kids.append(fpart(F, "BoardCrossH", [0.32, 0.35, 1.3], (-4.3, 4.4, -3.4), rgb(255, 255, 255), "SmoothPlastic", lrot=angles(-12, 0, 8), collide=False))
    kids.append(ellip("RescueTube", [3.4, 0.55, 0.55], F.p(1.8, deck_y + 1.6, -4.85), rgb(220, 40, 40), "SmoothPlastic", rot=F.r(), collide=False))
    kids.append(fpart(F, "FirstAid", [1.0, 0.8, 0.3], (2.6, deck_y + 0.9, -2.25), rgb(250, 250, 250), "SmoothPlastic", collide=False,
                      children=[sign_gui("✚", rgb(220, 30, 30), face="Front", ppu=40)]))
    for bx in (-0.25, 0.25):
        kids.append(fpart(F, "Binocular", [0.5, 0.26, 0.26], (0.8 + bx, deck_y + 1.85, -2.3), rgb(30, 30, 34), "Metal", lrot=CYL_Z(), shape="Cylinder", collide=False))
    # a bench in the shade under the hut, and a cooler
    for i in range(3):
        kids.append(fpart(F, f"BenchSeat{i}", [4.2, 0.18, 0.42], (0, 1.3, 1.2 + i * 0.46), wood, "WoodPlanks"))
    for sx in (-1.8, 1.8):
        kids.append(fpart(F, "BenchLeg", [0.3, 1.3, 1.3], (sx, 0.65, 1.66), trim, "Wood"))
    kids.append(fpart(F, "Cooler", [1.6, 1.1, 1.0], (2.4, 0.55, -1.0), rgb(40, 120, 200), "SmoothPlastic"))
    kids.append(fpart(F, "CoolerLid", [1.7, 0.25, 1.1], (2.4, 1.2, -1.0), rgb(250, 250, 250), "SmoothPlastic"))
    return folder("LifeguardHut", kids, "Model")

# ---------------------------------------------------------------- zones
ZONES = [
    ("StartingBeach", "Starting Beach", 1, 0, rgb(240, 214, 160)),
    ("RockyShore", "Rocky Shore", 4, 750, rgb(198, 186, 160)),
    ("TropicalIsland", "Tropical Island", 8, 6000, rgb(255, 244, 214)),
    ("AbandonedPier", "Abandoned Pier", 13, 35000, rgb(214, 190, 146)),
    ("ShipwreckCoast", "Shipwreck Coast", 19, 250000, rgb(176, 156, 124)),
    ("AncientRuins", "Ancient Ruins", 26, 1500000, rgb(226, 206, 160)),
]
ZW, ZD, ZCZ = 150, 110, 40  # dig area width (x), depth (z), centre z
# Each beach has its own ground (terrain material; colours are set in EnvironmentService):
#   golden sand, coarse grey shingle sand (Salt), white powder sand (Snow), weathered brown sand
#   (Sandstone), dark wet volcanic sand (Mud), pale ruin sand
GROUND = {"StartingBeach": "Sand", "RockyShore": "Salt", "TropicalIsland": "Snow", "AbandonedPier": "Sandstone",
          "ShipwreckCoast": "Mud", "AncientRuins": "Sand"}
zones_children = []

def zone_decor(zid, cx):
    d = []
    if zid == "StartingBeach":
        for i, (ox, oz, col) in enumerate([(-55, 78, rgb(230, 70, 70)), (-25, 82, rgb(60, 140, 230)), (35, 80, rgb(250, 200, 50)), (60, 70, rgb(70, 200, 120))]):
            d.append(umbrella(f"Umbrella{i}", cx + ox, oz, col))
        d.append(lifeguard_hut(cx - 62, 66))
        d.append(beach_flag("FlagWest", cx - 40, 2)); d.append(beach_flag("FlagEast", cx + 40, 2))
        d.append(sand_fence("SandFence", cx - 50, 92, cx + 8))
        for i, (ox, oz) in enumerate([(-72, 82), (-48, 88), (-30, 92), (-8, 90), (14, 92), (44, 90), (58, 86), (72, 80), (-70, 46), (70, 40)]):
            d.append(dune_grass(f"DuneGrass{i}", cx + ox, oz))
        for i, (ox, oz) in enumerate([(-58, 92), (50, 93), (68, 60)]):
            d.append(sea_grape(f"SeaGrape{i}", cx + ox, oz))
        d.append(driftwood("Driftwood0", cx + 30, 8)); d.append(driftwood("Driftwood1", cx - 20, -6))
        d.append(folder("Sandcastle", [
            part("Base", [6, 2, 6], [cx + 10, 1, 86], rgb(225, 196, 140), "Sand"),
            part("Tower1", [2, 3, 2], [cx + 8, 3, 84], rgb(225, 196, 140), "Sand"), part("Tower2", [2, 3, 2], [cx + 12, 3, 84], rgb(225, 196, 140), "Sand"),
            part("Tower3", [2, 3, 2], [cx + 8, 3, 88], rgb(225, 196, 140), "Sand"), part("Tower4", [2, 3, 2], [cx + 12, 3, 88], rgb(225, 196, 140), "Sand"),
            part("Flag", [0.1, 1.2, 1.6], [cx + 12, 5.5, 88], rgb(230, 60, 60), "Fabric"),
        ], "Model"))
        d.append(palm("Palm1", cx - 70, 90, 16)); d.append(palm("Palm2", cx + 70, 88, 18)); d.append(palm("Palm3", cx + 64, 72, 15))
        d.append(sign("WelcomeSign", [cx + 22, 7, 93], [16, 5, 0.6], "🏖 STARTING BEACH\nHold your detector & follow the beeps!", [0, 0, -1]))
    elif zid == "RockyShore":
        for i in range(16):
            side = random.choice([-1, 1])
            x = cx + random.uniform(-70, 70); z = random.choice([random.uniform(70, 92), random.uniform(-14, -6)])
            d.append(rock(f"Rock{i}", x, z, random.uniform(3, 8)))
        for i in range(5):
            d.append(rock(f"Boulder{i}", cx + random.uniform(-60, 60), random.uniform(10, 65), random.uniform(2.5, 4.5), rgb(120, 118, 112)))
        for i, (ox, oz) in enumerate([(-40, -8), (30, -10)]):
            d.append(part(f"TidePool{i}", [0.3, 10, 14], [cx + ox, 0.1, oz], rgb(70, 170, 190), "Glass", rot=angles(0, 0, 90), shape="Cylinder", transparency=0.3))
        d.append(folder("Lighthouse", [
            part("Base", [16, 8, 8], [cx + 62, 6, 98], rgb(120, 118, 112), "Slate", rot=angles(0, 0, 90), shape="Cylinder"),
            part("Tower", [26, 6, 6], [cx + 62, 23, 98], rgb(245, 245, 245), rot=angles(0, 0, 90), shape="Cylinder"),
            part("Stripe", [4, 6.2, 6.2], [cx + 62, 22, 98], rgb(220, 50, 50), rot=angles(0, 0, 90), shape="Cylinder"),
            part("Lamp", [4, 4.5, 4.5], [cx + 62, 38, 98], rgb(255, 230, 120), "Neon", rot=angles(0, 0, 90), shape="Cylinder"),
            part("Cap", [2, 5.5, 5.5], [cx + 62, 41, 98], rgb(60, 60, 60), "Metal", rot=angles(0, 0, 90), shape="Cylinder"),
            part("Stripe2", [3, 6.2, 6.2], [cx + 62, 30, 98], rgb(220, 50, 50), rot=angles(0, 0, 90), shape="Cylinder"),
            part("Gallery", [0.6, 9, 9], [cx + 62, 36, 98], rgb(60, 60, 64), "Metal", rot=angles(0, 0, 90), shape="Cylinder"),
            part("GalleryRail", [1.4, 9.2, 9.2], [cx + 62, 36.9, 98], rgb(40, 40, 44), "DiamondPlate", rot=angles(0, 0, 90), shape="Cylinder", transparency=0.55),
            part("LampGlass", [4.2, 5, 5], [cx + 62, 38.4, 98], rgb(230, 245, 255), "Glass", rot=angles(0, 0, 90), shape="Cylinder", transparency=0.6,
                 children=[{"name": "Beam", "className": "SpotLight", "properties": {"Brightness": 3, "Range": 60, "Angle": 35, "Color": rgb(255, 240, 180), "Face": "Front"}}]),
            part("Dome", [3.2, 3.2, 3.2], [cx + 62, 42.4, 98], rgb(60, 60, 60), "Metal", shape="Ball"),
            part("Door", [0.3, 3.6, 2.2], [cx + 62, 13.6, 94.9], rgb(120, 50, 40), "WoodPlanks", rot=angles(0, 90, 0)),
            part("Window1", [0.2, 1.4, 0.9], [cx + 62, 20, 94.95], rgb(60, 70, 90), "Glass", rot=angles(0, 90, 0)),
            part("Window2", [0.2, 1.4, 0.9], [cx + 62, 27, 94.95], rgb(60, 70, 90), "Glass", rot=angles(0, 90, 0)),
        ], "Model"))
        for i, (ox, oz) in enumerate([(-70, 88), (-50, 94), (-18, 92), (20, 94), (40, 90)]):
            d.append(coastal_pine(f"Pine{i}", cx + ox, oz, random.uniform(14, 20)))
        for i, (ox, oz) in enumerate([(-62, 76), (-34, 84), (8, 82), (30, 86), (70, 70)]):
            d.append(dune_grass(f"DryGrass{i}", cx + ox, oz, dry=True))
        for i, (ox, oz) in enumerate([(-10, -4), (52, 4), (-60, 10)]):
            d.append(driftwood(f"Driftwood{i}", cx + ox, oz))
    elif zid == "TropicalIsland":
        for i in range(10):
            x = cx + random.uniform(-70, 70); z = random.choice([random.uniform(74, 93), random.uniform(-12, -4)])
            d.append(palm(f"Palm{i}", x, z, random.uniform(14, 22)))
        d.append(folder("TikiHut", [
            part("Floor", [12, 1, 10], [cx - 50, 0.5, 86], rgb(150, 110, 70), "WoodPlanks"),
            part("Post1", [1, 8, 1], [cx - 55, 4.5, 82], rgb(120, 85, 50), "Wood"), part("Post2", [1, 8, 1], [cx - 45, 4.5, 82], rgb(120, 85, 50), "Wood"),
            part("Post3", [1, 8, 1], [cx - 55, 4.5, 90], rgb(120, 85, 50), "Wood"), part("Post4", [1, 8, 1], [cx - 45, 4.5, 90], rgb(120, 85, 50), "Wood"),
            part("RoofL", [14, 1, 7], [cx - 50, 10, 83.5], rgb(200, 170, 90), "Grass", rot=angles(25, 0, 0)),
            part("RoofR", [14, 1, 7], [cx - 50, 10, 88.5], rgb(200, 170, 90), "Grass", rot=angles(-25, 0, 0)),
        ], "Model"))
        for i, (ox, oz) in enumerate([(-66, 70), (-30, 90), (6, 86), (36, 92), (64, 80), (-10, 4)]):
            d.append(hibiscus(f"Hibiscus{i}", cx + ox, oz))
        for i, (ox, oz) in enumerate([(-44, 80), (50, 70)]):
            d.append(sea_grape(f"SeaGrape{i}", cx + ox, oz))
        for i, ox in enumerate([-20, 0, 20]):
            d.append(folder(f"Tiki{i}", [
                part("Body", [2.4, 6, 2.4], [cx + ox, 3, 92], rgb(130, 90, 50), "Wood"),
                part("Eyes", [1.6, 0.5, 0.2], [cx + ox, 4.6, 90.75], rgb(255, 210, 60), "Neon"),
            ], "Model"))
    elif zid == "AbandonedPier":
        planks = []
        for i in range(14):
            z = -14 - i * 5
            if i in (9,): continue  # a gap where the pier broke
            planks.append(part(f"Deck{i}", [10, 0.6, 4.8], [cx, 2.2, z], rgb(140, 110, 80), "WoodPlanks", rot=angles(0, 0, random.uniform(-2, 2))))
            for sx in (-4.5, 4.5):
                planks.append(part(f"Post{i}{'L' if sx < 0 else 'R'}", [9, 0.9, 0.9], [cx + sx, -2.5, z], rgb(90, 70, 50), "Wood", rot=angles(0, 0, 90), shape="Cylinder"))
        d.append(folder("Pier", planks, "Model"))
        d.append(folder("Shack", [
            part("Walls", [12, 8, 10], [cx + 50, 4, 86], rgb(110, 90, 70), "WoodPlanks", rot=angles(0, 8, 0)),
            part("Roof", [14, 1, 12], [cx + 50, 8.8, 86], rgb(80, 60, 45), "CorrodedMetal", rot=angles(4, 8, 6)),
        ], "Model"))
        for i in range(6):
            d.append(part(f"Crate{i}", [3, 3, 3], [cx + random.uniform(-70, -30), 1.5, random.uniform(78, 92)], rgb(150, 115, 70), "WoodPlanks", rot=angles(0, random.uniform(0, 90), 0)))
        # an old upturned rowboat and coils of rope
        bx, bz = cx - 18, 84
        d.append(folder("Rowboat", [
            ellip("Hull", [9, 2.4, 3.6], [bx, 0.8, bz], rgb(70, 110, 120), "WoodPlanks", rot=angles(0, 15, 180)),
            ellip("Keel", [9.4, 0.5, 0.5], [bx, 2.0, bz], rgb(110, 84, 60), "Wood", rot=angles(0, 15, 0)),
            part("Oar", [6, 0.3, 0.3], [bx + 2, 0.3, bz - 3], rgb(150, 115, 80), "Wood", rot=angles(0, 60, 90 - 90), shape="Cylinder"),
        ], "Model"))
        for i, (ox, oz) in enumerate([(-6, 90), (24, 92)]):
            d.append(folder(f"Rope{i}", [part("Coil", [0.6, 2.4, 2.4], [cx + ox, 0.3, oz], rgb(196, 170, 120), "Fabric", rot=angles(0, 0, 90), shape="Cylinder"),
                                          part("Hole", [0.7, 1.0, 1.0], [cx + ox, 0.32, oz], rgb(150, 126, 90), "Fabric", rot=angles(0, 0, 90), shape="Cylinder")], "Model"))
        for i, (ox, oz) in enumerate([(-66, 90), (-40, 94), (30, 82), (66, 88)]):
            d.append(dune_grass(f"DryGrass{i}", cx + ox, oz, dry=True))
        for i, (ox, oz) in enumerate([(-44, 6), (30, -2)]):
            d.append(driftwood(f"Driftwood{i}", cx + ox, oz))
        for i, ox in enumerate([-30, 10, 45]):
            d.append(folder(f"Lamp{i}", [
                part("Pole", [10, 0.5, 0.5], [cx + ox, 5, 94], rgb(50, 50, 55), "Metal", rot=angles(0, 0, 90), shape="Cylinder"),
                part("Light", [1.2, 1.2, 1.2], [cx + ox, 10.4, 94], rgb(255, 220, 140), "Neon", shape="Ball", children=[{"name": "Light", "className": "PointLight", "properties": {"Brightness": 1.5, "Range": 18, "Color": rgb(255, 210, 140)}}]),
            ], "Model"))
    elif zid == "ShipwreckCoast":
        wreck = []
        base = [cx + 35, 0, 70]
        R = angles(0, 30, 14)
        def W(name, size, off, col, mat="WoodPlanks", extra_rot=IDENT, shape=None, collide=True):
            p = apply(R, off); wreck.append(part(name, size, [base[0]+p[0], base[1]+p[1], base[2]+p[2]], col, mat, rot=matmul(R, extra_rot), shape=shape, collide=collide))
        def WE(name, size, off, col, mat="WoodPlanks", extra_rot=IDENT, collide=True):
            p = apply(R, off); wreck.append(ellip(name, size, [base[0]+p[0], base[1]+p[1], base[2]+p[2]], col, mat, rot=matmul(R, extra_rot), collide=collide))
        hull, dark, plank = rgb(96, 70, 48), rgb(64, 46, 32), rgb(140, 105, 70)
        # a rounded hull (half buried, listing), a pointed bow and a tall stern castle
        WE("Hull", [11, 10, 36], [0, 2.4, 0], hull)
        WE("Bow", [8, 8.5, 12], [0, 3.2, -17], hull)
        W("Stern", [10, 6, 7], [0, 8.5, 13], hull)
        W("SternRail", [10.4, 0.5, 0.5], [0, 11.7, 9.8], dark, "Wood")
        W("Deck", [9, 0.5, 28], [0, 7.3, -1], plank)
        # broken planks along the hull side and a hole where the sea got in
        for i in range(6):
            W(f"Strake{i}", [0.4, 0.7, 28 - i * 2], [5.4 - i * 0.15, 6.4 - i * 1.1, 0], dark, "WoodPlanks", collide=False)
        W("Breach", [0.6, 3.2, 5], [5.2, 3.4, 4], rgb(30, 22, 16), "SmoothPlastic", collide=False)
        for i, z in enumerate((-8, -2, 4)):
            W(f"Gunport{i}", [0.5, 1.2, 1.4], [5.5, 5.6, z], rgb(30, 22, 16), "SmoothPlastic", collide=False)
            W(f"Cannon{i}", [3, 0.9, 0.9], [6.4, 5.6, z], rgb(40, 40, 45), "Metal", shape="Cylinder", collide=False)
        # snapped main mast with a crow's nest, a fallen spar and a torn sail
        W("Mast", [18, 1.4, 1.4], [0, 16, -2], rgb(110, 80, 50), "Wood", extra_rot=angles(0, 0, 90), shape="Cylinder")
        W("MastBreak", [1.6, 1.5, 1.5], [0, 25, -2], rgb(150, 115, 80), "Wood", extra_rot=angles(20, 0, 70), collide=False)
        W("Nest", [1.6, 3.2, 3.2], [0, 21.5, -2], dark, "WoodPlanks", extra_rot=angles(0, 0, 90), shape="Cylinder", collide=False)
        W("Spar", [16, 0.8, 0.8], [1, 18, -2], rgb(110, 80, 50), "Wood", extra_rot=angles(0, 90, 18), shape="Cylinder", collide=False)
        W("Sail", [0.2, 7, 9], [0.4, 14, -2], rgb(222, 210, 186), "Fabric", extra_rot=angles(8, 90, 0), collide=False)
        W("SailTear", [0.25, 2.6, 2.2], [0.5, 12.6, 0.8], rgb(30, 22, 16), "SmoothPlastic", extra_rot=angles(8, 90, 30), collide=False)
        W("Bowsprit", [10, 0.8, 0.8], [0, 7, -25], rgb(110, 80, 50), "Wood", extra_rot=angles(0, 90, -18), shape="Cylinder", collide=False)
        W("Figurehead", [1.4, 2.4, 1.4], [0, 6.2, -23], rgb(214, 180, 80), "Metal", collide=False)
        d.append(folder("Shipwreck", wreck, "Model"))
        for i in range(8):
            d.append(folder(f"Barrel{i}", [part("Barrel", [2.8, 2.2, 2.2], [cx + random.uniform(-70, 0), 1.1, random.uniform(-12, 92) if i % 2 else random.uniform(80, 92)], rgb(120, 85, 50), "Wood", rot=angles(0, random.uniform(0, 180), 90 if i % 3 else 0), shape="Cylinder")], "Model"))
        for i in range(8):
            d.append(rock(f"Rock{i}", cx + random.uniform(-72, 72), random.choice([random.uniform(80, 93), random.uniform(-14, -8)]), random.uniform(3, 7), rgb(90, 88, 84)))
        # ribs of an older wreck poking out of the black sand
        ribs = []
        for i in range(7):
            for side in (-1, 1):
                ribs.append(part(f"Rib{i}{side}", [0.9, 7 - abs(i - 3) * 0.7, 0.9], [cx - 40 + i * 2.6, 2.4, 78 + side * 3.2], rgb(70, 52, 38), "Wood",
                                 rot=angles(side * 22, 0, 0), collide=False))
        ribs.append(part("Keelson", [18, 0.9, 0.9], [cx - 32, 0.2, 78], rgb(64, 48, 34), "Wood"))
        d.append(folder("OldRibs", ribs, "Model"))
        for i in range(8):
            kx, kz = cx + random.uniform(-70, 70), random.uniform(-10, 0)
            d.append(part(f"Kelp{i}", [0.3, random.uniform(1.5, 3), 0.9], [kx, 0.6, kz], rgb(50, 80, 40), "Grass", rot=angles(random.uniform(-30, 30), random.uniform(0, 180), random.uniform(-30, 30)), collide=False))
        d.append(driftwood("Driftwood0", cx + 10, 84))
    elif zid == "AncientRuins":
        for i, ox in enumerate([-60, -40, -20, 20, 40, 60]):
            d.append(column(f"Column{i}", cx + ox, 88, random.choice([10, 14, 16]), broken=(i % 3 == 1)))
        d.append(folder("Arch", [
            part("LeftPillar", [3, 14, 3], [cx - 6, 7, 70], rgb(220, 210, 180), "Marble"),
            part("RightPillar", [3, 14, 3], [cx + 6, 7, 70], rgb(220, 210, 180), "Marble"),
            part("Top", [16, 3, 3.4], [cx, 15.5, 70], rgb(220, 210, 180), "Marble"),
        ], "Model"))
        for i in range(4):
            d.append(part(f"Step{i}", [30 - i * 6, 1, 6 - i], [cx, 0.5 + i, 96 - i * 1.5], rgb(214, 200, 168), "Marble"))
        d.append(folder("StatueHead", [
            part("Head", [7, 8, 7], [cx - 50, 3, 30], rgb(190, 180, 150), "Slate", rot=angles(0, 20, 18)),
            part("Crown", [7.6, 1.6, 7.6], [cx - 51, 7.6, 30], rgb(230, 190, 80), "Metal", rot=angles(0, 20, 18)),
        ], "Model"))
        for i, (ox, oz) in enumerate([(-70, 80), (-30, 94), (30, 92), (70, 82)]):
            d.append(hibiscus(f"JunglePlant{i}", cx + ox, oz))
        for i, (ox, oz) in enumerate([(-50, 92), (50, 94)]):
            d.append(coastal_pine(f"Cypress{i}", cx + ox, oz, random.uniform(18, 22)))
        for i in range(10):
            d.append(part(f"Rubble{i}", [random.uniform(1.5, 3.5)] * 3, [cx + random.uniform(-70, 70), 0.8, random.uniform(-12, 92) if i % 2 else random.uniform(78, 94)], rgb(205, 195, 165), "Marble", rot=angles(random.uniform(0, 40), random.uniform(0, 90), random.uniform(0, 40))))
    return d

def unlock_station(x, z, zname, lvl, price):
    """The stand beside a beach barrier where that beach is bought (prompt added by the client)."""
    brass, wood = rgb(255, 205, 90), rgb(120, 82, 52)
    price_text = "${:,}".format(price)
    return folder("UnlockStation", [
        part("Base", [0.8, 4.2, 4.2], [x, 0.4, z], rgb(222, 214, 198), "Slate", rot=angles(0, 0, 90), shape="Cylinder"),
        part("Post", [3.2, 1.0, 1.0], [x, 2.4, z], wood, "Wood", rot=angles(0, 0, 90), shape="Cylinder"),
        part("Lectern", [2.8, 0.35, 2.2], [x + 0.2, 4.1, z], wood, "WoodPlanks", rot=angles(0, 0, 22)),
        part("Map", [2.4, 0.08, 1.8], [x + 0.25, 4.32, z], rgb(245, 228, 190), "SmoothPlastic", rot=angles(0, 0, 22),
             children=[sign_gui(f"🔓 {zname.upper()}\nLv {lvl} · {price_text}", rgb(110, 60, 20), face="Top", ppu=40)]),
        part("LockBody", [1.3, 1.1, 0.6], [x - 0.6, 5.7, z], brass, "Metal"),
        part("LockShackle", [0.25, 1.1, 1.1], [x - 0.6, 6.4, z], brass, "Metal", rot=angles(0, 90, 0), shape="Cylinder"),
        part("Lantern", [0.8, 0.8, 0.8], [x - 0.6, 7.6, z], rgb(255, 130, 90), "Neon", shape="Ball",
             children=[{"name": "Light", "className": "PointLight", "properties": {"Brightness": 1, "Range": 12, "Color": rgb(255, 160, 110)}}]),
        part("PromptAnchor", [1, 1, 1], [x, 5.0, z], rgb(255, 255, 255), transparency=1, collide=False, query=False, shadow=False),
    ], "Model")

for i, (zid, zname, lvl, price, color) in enumerate(ZONES):
    cx = i * 170
    kids = [
        part("DigArea", [ZW, 6, ZD], [cx, -3, ZCZ], color, "Sand", attrs={"ZoneId": zid, "TerrainMaterial": GROUND[zid]}),
        # the wet band where the waves reach (Ground terrain, coloured like wet sand)
        part("ShoreSlope", [ZW, 8, 22], [cx, -4, -26], color, "Sand", cls="WedgePart", attrs={"TerrainMaterial": "Ground"}),
        part("Region", [ZW + 0.5, 90, 300], [cx, 25, -50], rgb(255, 255, 255), transparency=1, collide=False, query=False, shadow=False, attrs={"ZoneId": zid}),
        part("TravelPoint", [4, 1, 4], [cx, 2, 60], rgb(255, 255, 255), transparency=1, collide=False, query=False, shadow=False),
        folder("Decor", zone_decor(zid, cx)),
    ]
    if i > 0:
        gx = cx - 85
        kids.append(part("Gate", [3, 26, ZD + 6], [gx, 13, ZCZ], rgb(220, 80, 70), "ForceField", transparency=0.35, shadow=False, attrs={"ZoneId": zid}))
        kids.append(part("GateSea", [3, 60, 186], [gx, 10, -108], rgb(255, 255, 255), transparency=1, shadow=False, query=False))
        kids.append(sign("ZoneSign", [gx + 10, 8, ZCZ - 52], [14, 4.5, 0.6], f"{zname.upper()}\nLevel {lvl}", [-1, 0, 0]))
        kids.append(unlock_station(gx - 7, 74, zname, lvl, price))
    zones_children.append(folder(zid, kids))
    # walkway between this zone and the next
    if i < len(ZONES) - 1:
        zones_children[-1]["children"].append(part("Walkway", [20.2, 6, ZD], [cx + 85, -3, ZCZ], color, "Sand", attrs={"TerrainMaterial": "Sand"}))
        zones_children[-1]["children"].append(part("WalkwayShore", [20.2, 8, 22], [cx + 85, -4, -26], color, "Sand", cls="WedgePart", attrs={"TerrainMaterial": "Ground"}))

# Secret Treasure Island (teleport only)
SX, SZ = 425, -330
secret_kids = [
    part("DigArea", [150, 8, 110], [SX, -4, SZ], rgb(250, 222, 135), "Sand", attrs={"ZoneId": "SecretIsland", "TerrainMaterial": "Sand"}),
    part("SlopeSouth", [150, 8, 20], [SX, -4, SZ - 65], rgb(235, 205, 120), "Sand", cls="WedgePart", attrs={"TerrainMaterial": "Sand"}),
    part("SlopeNorth", [150, 8, 20], [SX, -4, SZ + 65], rgb(235, 205, 120), "Sand", cls="WedgePart", rot=angles(0, 180, 0), attrs={"TerrainMaterial": "Sand"}),
    part("SlopeWest", [110, 8, 20], [SX - 85, -4, SZ], rgb(235, 205, 120), "Sand", cls="WedgePart", rot=angles(0, 90, 0), attrs={"TerrainMaterial": "Sand"}),
    part("SlopeEast", [110, 8, 20], [SX + 85, -4, SZ], rgb(235, 205, 120), "Sand", cls="WedgePart", rot=angles(0, -90, 0), attrs={"TerrainMaterial": "Sand"}),
    part("Region", [200, 90, 170], [SX, 25, SZ], rgb(255, 255, 255), transparency=1, collide=False, query=False, shadow=False, attrs={"ZoneId": "SecretIsland"}),
    part("TravelPoint", [4, 1, 4], [SX, 2, SZ + 40], rgb(255, 255, 255), transparency=1, collide=False, query=False, shadow=False),
]
sdecor = [palm(f"Palm{i}", SX + x, SZ + z, random.uniform(16, 24)) for i, (x, z) in enumerate([(-70, -48), (-60, 50), (68, 46), (72, -40), (-20, 52), (30, -52)])]
sdecor.append(folder("SkullRock", [
    part("Skull", [26, 26, 26], [SX - 52, 8, SZ - 30], rgb(150, 140, 120), "Slate", shape="Ball"),
    part("EyeL", [6, 6, 6], [SX - 58, 12, SZ - 19], rgb(20, 20, 25), shape="Ball"),
    part("EyeR", [6, 6, 6], [SX - 46, 12, SZ - 19], rgb(20, 20, 25), shape="Ball"),
], "Model"))
sdecor.append(folder("GoldenStatue", [
    part("Plinth", [8, 3, 8], [SX + 55, 1.5, SZ + 30], rgb(230, 220, 200), "Marble"),
    part("Body", [3.5, 9, 3], [SX + 55, 7.5, SZ + 30], rgb(255, 205, 60), "Metal"),
    part("Head", [3.4, 3.4, 3.4], [SX + 55, 13.6, SZ + 30], rgb(255, 205, 60), "Metal", shape="Ball"),
    part("Glow", [1, 1, 1], [SX + 55, 16, SZ + 30], rgb(255, 230, 120), "Neon", shape="Ball", children=[{"name": "Light", "className": "PointLight", "properties": {"Brightness": 2, "Range": 24, "Color": rgb(255, 210, 100)}}]),
], "Model"))
for i in range(12):
    sdecor.append(part(f"Gold{i}", [1.4, 1.4, 1.4], [SX + 50 + random.uniform(-5, 5), 0.6, SZ - 40 + random.uniform(-4, 4)], rgb(255, 205, 50), "Metal", shape="Ball"))
secret_kids.append(folder("Decor", sdecor))
zones_children.append(folder("SecretIsland", secret_kids))

# ---------------------------------------------------------------- boundaries (cliffs + invisible walls)
bounds = [
    part("BackCliff", [930, 40, 14], [75 + 930/2, 20, 102], rgb(150, 140, 125), "Slate", attrs={"TerrainMaterial": "Rock"}),
    part("WestCliff", [14, 40, 130], [-82, 20, 40], rgb(150, 140, 125), "Slate", attrs={"TerrainMaterial": "Rock"}),
    part("EastCliff", [14, 40, 130], [932, 20, 40], rgb(150, 140, 125), "Slate", attrs={"TerrainMaterial": "Rock"}),
    part("HubWestHedge", [6, 10, 135], [-83, 5, 162], rgb(60, 140, 70), "Grass", attrs={"TerrainMaterial": "LeafyGrass"}),
    part("HubEastHedge", [6, 10, 135], [83, 5, 162], rgb(60, 140, 70), "Grass", attrs={"TerrainMaterial": "LeafyGrass"}),
    part("StreetWest", [4, 40, 82], [-214, 20, 270], rgb(255, 255, 255), transparency=1, shadow=False),
    part("StreetEast", [4, 40, 82], [214, 20, 270], rgb(255, 255, 255), transparency=1, shadow=False),
    part("StreetHedgeWest", [133, 10, 4], [-149.5, 5, 229], rgb(60, 140, 70), "Grass"),
    part("StreetHedgeEast", [133, 10, 4], [149.5, 5, 229], rgb(60, 140, 70), "Grass"),
    part("StreetNorth", [432, 40, 4], [0, 20, 313], rgb(255, 255, 255), transparency=1, shadow=False),
    part("SeaWestWall", [4, 60, 460], [-160, 10, -220], rgb(255, 255, 255), transparency=1, shadow=False),
    part("SeaEastWall", [4, 60, 460], [1010, 10, -220], rgb(255, 255, 255), transparency=1, shadow=False),
    part("SeaSouthWall", [1180, 60, 4], [425, 10, -452], rgb(255, 255, 255), transparency=1, shadow=False),
]
for i in range(18):
    x = 90 + i * 48 + random.uniform(-8, 8)
    bounds.append(rock(f"CliffRock{i}", x, 97, random.uniform(6, 11), rgb(140, 132, 118)))

# ---------------------------------------------------------------- hub town
hub = [
    part("Plaza", [160, 6, 135], [0, -3, 162.5], rgb(110, 175, 90), "Grass"),
    part("Boardwalk", [16, 0.6, 50], [0, 0.3, 120], rgb(170, 130, 90), "WoodPlanks"),
    part("PlazaStone", [70, 0.4, 70], [0, 0.2, 168], rgb(210, 200, 180), "Cobblestone"),
    part("HubPoint", [4, 1, 4], [0, 2, 150], rgb(255, 255, 255), transparency=1, collide=False, query=False, shadow=False),
    {"name": "SpawnLocation", "className": "SpawnLocation", "properties": {"Anchored": True, "Size": [12, 1, 12], "CFrame": cf([0, 0.9, 150]),
        "Color": rgb(60, 190, 200), "Material": "SmoothPlastic", "Duration": 0, "Neutral": True, "TopSurface": "Smooth", "BottomSurface": "Smooth"},
     "children": [{"name": "Decal", "className": "SurfaceGui", "properties": {"Face": "Top", "SizingMode": "PixelsPerStud", "PixelsPerStud": 20, "LightInfluence": 0},
                   "children": [{"name": "Label", "className": "TextLabel", "properties": {"Text": "🏖", "TextScaled": True, "BackgroundTransparency": 1, "Size": udim2(1, 0, 1, 0), "Font": "FredokaOne", "TextColor3": rgb(255, 255, 255)}}]}]},
]


# ---------------------------------------------------------------- storefronts + NPC shopkeepers
SKIN = {"light": rgb(240, 196, 160), "tan": rgb(214, 160, 118), "brown": rgb(150, 100, 70), "pale": rgb(250, 222, 196)}

def npc(F, npc_id, name, role, action, skin, shirt, sleeves, pants, extras, lpos=(0, 0.4, 3.8)):
    ox, oy, oz = lpos
    def P(nm, size, l, color, material="SmoothPlastic", lrot=IDENT, rig="Torso", **kw):
        a = {"Rig": rig}
        return fpart(F, nm, size, (ox + l[0], oy + l[1], oz + l[2]), color, material, lrot=lrot, attrs=a, **kw)
    root = fpart(F, "HumanoidRootPart", [2, 2, 1], (ox, oy + 3, oz), rgb(255, 255, 255), transparency=1, collide=False, shadow=False,
                 attrs={"Rig": "Root"},
                 children=[{"name": "Prompt", "className": "ProximityPrompt",
                            "properties": {"ActionText": action, "ObjectText": f"{name} · {role}", "HoldDuration": 0,
                                           "MaxActivationDistance": 12, "RequiresLineOfSight": False},
                            "attributes": {"NPCId": npc_id}}])
    head = P("Head", [1.25, 1.25, 1.25], (0, 4.63, 0), skin, rig="Head", children=[
        {"name": "Mesh", "className": "SpecialMesh", "properties": {"MeshType": "Head", "Scale": [1, 1, 1]}},
        {"name": "face", "className": "Decal", "properties": {"Texture": "rbxasset://textures/face.png", "Face": "Front"}},
        {"name": "NameTag", "className": "BillboardGui", "properties": {"Size": udim2(0, 230, 0, 58), "StudsOffset": [0, 2.3, 0], "MaxDistance": 70, "LightInfluence": 0},
         "children": [
            {"name": "Name", "className": "TextLabel", "properties": {"Text": name, "Font": "FredokaOne", "TextScaled": True, "BackgroundTransparency": 1,
              "TextColor3": rgb(255, 255, 255), "TextStrokeTransparency": 0.3, "Size": udim2(1, 0, 0.58, 0)}},
            {"name": "Role", "className": "TextLabel", "properties": {"Text": role, "Font": "GothamBold", "TextScaled": True, "BackgroundTransparency": 1,
              "TextColor3": rgb(255, 220, 130), "TextStrokeTransparency": 0.4, "Size": udim2(1, 0, 0.36, 0), "Position": udim2(0, 0, 0.62, 0)}},
         ]}])
    kids = [root, head,
        P("Torso", [2, 2, 1], (0, 3, 0), shirt),
        P("Left Arm", [1, 2, 1], (-1.5, 3, 0), sleeves, rig="LeftArm"),
        P("Right Arm", [1, 2, 1], (1.5, 3, 0), sleeves, rig="RightArm"),
        P("Left Leg", [1, 2, 1], (-0.5, 1, 0), pants, rig="Legs"),
        P("Right Leg", [1, 2, 1], (0.5, 1, 0), pants, rig="Legs"),
    ]
    for e in extras:
        nm, size, l, color = e[0], e[1], e[2], e[3]
        opt = e[4] if len(e) > 4 else {}
        kids.append(P(nm, size, l, color, opt.get("mat", "SmoothPlastic"), lrot=opt.get("rot", IDENT), rig=opt.get("rig", "Torso"),
                      shape=opt.get("shape"), collide=False, transparency=opt.get("t", 0)))
    return folder("NPC", kids, "Model", attrs={"NPCId": npc_id, "DisplayName": name})


def storefront(name, center, yaw, title, accent, npc_node_fn, props, W=18, shelves=True):
    F = Frame(center, yaw)
    h = W / 2
    cream, wood, dark = rgb(244, 232, 205), rgb(165, 118, 76), rgb(70, 52, 40)
    kids = [
        fpart(F, "Deck", [W, 0.4, 11], (0, 0.2, 3.5), rgb(178, 136, 92), "WoodPlanks"),
        fpart(F, "Counter", [W - 4, 3.4, 2.4], (0, 1.9, 0), wood, "WoodPlanks"),
        fpart(F, "CounterTop", [W - 3.4, 0.3, 2.9], (0, 3.75, 0), accent, "SmoothPlastic"),
        fpart(F, "BackWall", [W, 12, 0.8], (0, 6.4, 8.6), cream, "Wood"),
        fpart(F, "SideWallL", [0.8, 12, 8.6], (-(h - 0.4), 6.4, 4.3), cream, "Wood"),
        fpart(F, "SideWallR", [0.8, 12, 8.6], ((h - 0.4), 6.4, 4.3), cream, "Wood"),
        fpart(F, "PillarL", [12.4, 1.1, 1.1], (-(h - 0.4), 6.4, -0.4), dark, "Wood", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "PillarR", [12.4, 1.1, 1.1], ((h - 0.4), 6.4, -0.4), dark, "Wood", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "PillarFootL", [0.7, 1.7, 1.7], (-(h - 0.4), 0.75, -0.4), dark, "Wood", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "PillarFootR", [0.7, 1.7, 1.7], ((h - 0.4), 0.75, -0.4), dark, "Wood", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "CounterNose", [W - 3.4, 0.55, 0.55], (0, 3.75, -1.45), accent, "SmoothPlastic", shape="Cylinder"),
        fpart(F, "CounterKick", [W - 4.2, 0.6, 0.6], (0, 0.7, -1.2), dark, "Wood", shape="Cylinder"),
        fpart(F, "RoofNose", [W + 1.6, 0.8, 0.8], (0, 12.3, -1.9), dark, "Wood", shape="Cylinder"),
        ellip("Cupola", [6, 3.6, 5], F.p(0, 14.4, 4.6), accent, "SmoothPlastic", rot=F.r()),
        part("CupolaRing", [0.4, 6.3, 5.3], F.p(0, 14.0, 4.6), rgb(255, 205, 90), "Metal", rot=F.r(CYL_Y()), shape="Cylinder"),
        part("CupolaFinial", [0.9, 0.9, 0.9], F.p(0, 16.3, 4.6), rgb(255, 205, 90), "Metal", shape="Ball"),
        fpart(F, "Roof", [W + 1.6, 0.6, 11.4], (0, 12.9, 3.8), dark, "WoodPlanks", lrot=angles(-6, 0, 0)),
        fpart(F, "Sign", [min(W - 4, 20), 3.4, 0.4], (0, 15.2, -0.4), accent, "SmoothPlastic", children=[sign_gui(title, rgb(255, 255, 255), ppu=26)]),
        fpart(F, "SignFrame", [min(W - 4, 20), 4.0, 0.3], (0, 15.2, -0.15), rgb(255, 205, 90), "Metal"),
        fpart(F, "SignPostL", [2.2, 0.45, 0.45], (-5, 13.4, -0.2), dark, "Wood", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "SignPostR", [2.2, 0.45, 0.45], (5, 13.4, -0.2), dark, "Wood", lrot=CYL_Y(), shape="Cylinder"),
    ]
    # pill-shaped sign: round end caps with a brass rim
    sign_w = min(W - 4, 20)
    for sx in (-1, 1):
        kids.append(fpart(F, f"SignCap{'L' if sx < 0 else 'R'}", [0.4, 3.4, 3.4], (sx * sign_w / 2, 15.2, -0.4), accent, "SmoothPlastic", lrot=CYL_Z(), shape="Cylinder"))
        kids.append(fpart(F, f"SignRim{'L' if sx < 0 else 'R'}", [0.3, 4.0, 4.0], (sx * sign_w / 2, 15.2, -0.15), rgb(255, 205, 90), "Metal", lrot=CYL_Z(), shape="Cylinder"))
    if shelves:
        kids.append(fpart(F, "ShelfLow", [W - 4, 0.3, 1.3], (0, 5.4, 7.6), wood, "Wood"))
        kids.append(fpart(F, "ShelfHigh", [W - 4, 0.3, 1.3], (0, 8.6, 7.6), wood, "Wood"))
    # striped awning sloping down towards the customers
    stripes = int(round(W / 2.6)) | 1
    sw = (W + 0.6) / stripes
    for i in range(stripes):
        col = accent if i % 2 == 0 else rgb(255, 255, 255)
        kids.append(fpart(F, f"Awning{i}", [sw, 0.25, 3.4], (-(W + 0.6) / 2 + sw * (i + 0.5), 11.3, -1.9), col, "Fabric", lrot=angles(-20, 0, 0)))
        # scalloped valance: a soft rounded tab hanging from each stripe
        kids.append(ellip(f"Scallop{i}", [sw * 0.98, 1.1, 0.25], F.p(-(W + 0.6) / 2 + sw * (i + 0.5), 10.55, -3.45), col, "Fabric", rot=F.r(), collide=False))
    # lanterns + plants
    for sx in (-1, 1):
        kids.append(fpart(F, f"Lantern{'L' if sx < 0 else 'R'}", [0.8, 1.0, 0.8], (sx * (h - 0.4), 9.6, -1.1), rgb(255, 220, 140), "Neon",
                          children=[sphere_mesh(), {"name": "Light", "className": "PointLight", "properties": {"Brightness": 1.1, "Range": 14, "Color": rgb(255, 210, 150)}}]))
        kids.append(fpart(F, f"LanternCap{'L' if sx < 0 else 'R'}", [0.25, 0.9, 0.9], (sx * (h - 0.4), 10.15, -1.1), dark, "Metal", lrot=CYL_Y(), shape="Cylinder"))
        kids.append(fpart(F, f"Pot{'L' if sx < 0 else 'R'}", [1.6, 1.5, 1.5], (sx * (h + 1.6), 0.8, -1.2), rgb(190, 110, 70), "Slate", lrot=CYL_Y(), shape="Cylinder"))
        kids.append(fpart(F, f"Bush{'L' if sx < 0 else 'R'}", [2.4, 2.4, 2.4], (sx * (h + 1.6), 2.4, -1.2), rgb(70, 150, 70), "Grass", shape="Ball"))
    # festoon lights sagging across the front between the pillars
    span = W - 0.8
    for i in range(11):
        t = i / 10
        sag = 1.6 * (1 - (2 * t - 1) ** 2)
        kids.append(fpart(F, f"Bulb{i}", [0.42, 0.42, 0.42], (-span / 2 + span * t, 10.2 - sag, -0.9), rgb(255, 226, 150), "Neon", shape="Ball", collide=False, shadow=False,
                          children=[{"name": "Light", "className": "PointLight", "properties": {"Brightness": 0.5, "Range": 6, "Color": rgb(255, 214, 150)}}] if i % 3 == 1 else None))
    kids.append(fpart(F, "LightWire", [span, 0.05, 0.05], (0, 9.4, -0.9), rgb(40, 40, 40), "SmoothPlastic", collide=False, shadow=False))
    # chalkboard A-frame out front
    for side in (-1, 1):
        kids.append(fpart(F, f"ABoard{side}", [2.0, 2.6, 0.12], (h + 1.0, 1.25, -5.0 + side * 0.45), rgb(40, 44, 40), "Slate", lrot=angles(side * 12, 0, 0),
                          children=[sign_gui("OPEN\n☀ Come in!", rgb(255, 250, 230), face="Front" if side < 0 else "Back", ppu=24)]))
    # stock: crates and a barrel by the counter end
    kids.append(fpart(F, "Crate1", [1.8, 1.8, 1.8], (-(h - 2.2), 0.9, 5.6), rgb(170, 130, 85), "WoodPlanks"))
    kids.append(fpart(F, "Crate2", [1.4, 1.4, 1.4], (-(h - 2.0), 2.5, 5.7), rgb(160, 120, 78), "WoodPlanks", lrot=angles(0, 20, 0)))
    kids.append(fpart(F, "Barrel", [2.2, 1.6, 1.6], ((h - 2.0), 1.1, 5.6), rgb(130, 90, 55), "Wood", lrot=CYL_Y(), shape="Cylinder"))
    kids.append(fpart(F, "BarrelHoop", [0.2, 1.7, 1.7], ((h - 2.0), 1.5, 5.6), rgb(80, 80, 85), "Metal", lrot=CYL_Y(), shape="Cylinder", collide=False))
    if npc_node_fn:
        kids.append(npc_node_fn(F))
    kids.append(folder("Display", props(F)))
    return folder(name, kids, "Model")

# ---- display props per shop (local coordinates)
def detector_props(F):
    out = []
    for i, (x, col) in enumerate([(-4.5, rgb(40, 170, 190)), (0, rgb(255, 140, 60)), (4.5, rgb(255, 200, 60))]):
        out.append(fpart(F, f"DetShaft{i}", [0.18, 3.2, 0.18], (x, 7.6, 8.05), rgb(60, 60, 66), "Metal"))
        out.append(fpart(F, f"DetCoil{i}", [0.18, 1.6, 1.6], (x, 5.95, 7.95), col, "SmoothPlastic", lrot=CYL_Z(), shape="Cylinder"))
        out.append(fpart(F, f"DetBox{i}", [0.7, 0.5, 0.4], (x, 8.4, 7.9), col, "SmoothPlastic"))
        out.append(fpart(F, f"DetScreen{i}", [0.5, 0.3, 0.05], (x, 8.45, 7.68), rgb(140, 255, 200), "Neon"))
    out.append(fpart(F, "CounterDetector", [0.16, 2.6, 0.16], (-4, 4.9, 0.2), rgb(60, 60, 66), "Metal", lrot=angles(0, 0, 50)))
    out.append(fpart(F, "CounterCoil", [0.14, 1.2, 1.2], (-5.0, 4.0, 0.2), rgb(40, 170, 190), "SmoothPlastic", lrot=CYL_Y(), shape="Cylinder"))
    return out

def shovel_props(F):
    out = []
    for i, (x, shaft, blade, mat) in enumerate([(-5, rgb(240, 200, 60), rgb(220, 70, 60), "SmoothPlastic"), (-2, rgb(150, 105, 65), rgb(175, 130, 85), "WoodPlanks"),
                                               (1, rgb(120, 85, 55), rgb(120, 124, 130), "CorrodedMetal"), (4, rgb(60, 40, 30), rgb(255, 200, 60), "Metal")]):
        out.append(fpart(F, f"ShovelShaft{i}", [0.2, 4.6, 0.2], (x, 3.3, 7.7), shaft, "Wood", lrot=angles(-8, 0, 0)))
        out.append(fpart(F, f"ShovelBlade{i}", [1.2, 1.4, 0.15], (x, 0.95, 7.95), blade, mat, lrot=angles(-8, 0, 0)))
        out.append(fpart(F, f"ShovelGrip{i}", [0.8, 0.22, 0.22], (x, 5.6, 7.4), shaft, "Wood", shape="Cylinder"))
    out.append(fpart(F, "Barrel", [2.4, 2.2, 2.2], (6.6, 1.6, 6.4), rgb(120, 85, 50), "Wood", lrot=CYL_Y(), shape="Cylinder"))
    for j, dx in enumerate((-0.4, 0.4)):
        out.append(fpart(F, f"BarrelShaft{j}", [0.18, 3.2, 0.18], (6.6 + dx, 3.6, 6.4), rgb(150, 105, 65), "Wood", lrot=angles(0, 0, dx * 20)))
    return out

def appraiser_props(F):
    gold = rgb(255, 200, 60)
    out = [
        fpart(F, "ScaleBase", [0.3, 1.3, 1.3], (-3.5, 4.05, 0.1), gold, "Metal", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "ScalePost", [1.8, 0.18, 0.18], (-3.5, 5.1, 0.1), gold, "Metal", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "ScaleTop", [0.32, 0.32, 0.32], (-3.5, 6.1, 0.1), gold, "Metal", shape="Ball"),
        fpart(F, "ScaleBeam", [2.8, 0.12, 0.12], (-3.5, 6.0, 0.1), gold, "Metal"),
        fpart(F, "ScalePanL", [0.08, 1, 1], (-4.8, 5.3, 0.1), gold, "Metal", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "ScalePanR", [0.08, 1, 1], (-2.2, 5.3, 0.1), gold, "Metal", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "Chest", [3, 1.8, 2], (5.8, 1.3, 6.2), rgb(130, 85, 40), "Wood"),
        fpart(F, "ChestLid", [3.05, 2.05, 2.05], (5.8, 2.2, 6.2), rgb(110, 70, 35), "Wood", shape="Cylinder"),
        fpart(F, "ChestBand", [0.3, 2.45, 2.1], (5.8, 1.6, 6.2), gold, "Metal"),
    ]
    for i in range(9):
        out.append(fpart(F, f"Coin{i}", [0.6, 0.6, 0.6], (2.4 + (i % 3) * 0.55, 4.2 + (i // 3) * 0.35, -0.2 + (i % 2) * 0.3), gold, "Metal", shape="Ball"))
    for i, (x, col) in enumerate([(-4, rgb(220, 40, 60)), (-1.5, rgb(40, 120, 255)), (1, rgb(60, 220, 120)), (3.5, rgb(170, 90, 255))]):
        out.append(fpart(F, f"Gem{i}", [0.8, 0.8, 0.8], (x, 6.05, 7.6), col, "Glass", lrot=angles(45, 30, 45)))
    return out

def equipment_props(F):
    """Detectors on a pegboard (left), a shovel rack (middle), backpacks on a shelf (right)."""
    out = [fpart(F, "Pegboard", [24, 7.5, 0.2], (0, 7.2, 8.1), rgb(214, 186, 140), "Wood")]
    out += detector_props(F.shift(-8))
    out += [p for p in shovel_props(F.shift(1.5)) if not p["name"].startswith("Barrel")]
    out.append(fpart(F, "ShovelRackBar", [11, 0.3, 0.3], (1.5, 5.0, 7.6), rgb(70, 52, 40), "Wood"))
    out.append(fpart(F, "PackShelf", [6, 0.3, 1.3], (10.2, 5.6, 7.6), rgb(165, 118, 76), "Wood"))
    for i, (x, col) in enumerate([(8.8, rgb(240, 140, 50)), (11.4, rgb(130, 90, 200))]):
        out.append(fpart(F, f"Pack{i}", [1.8, 1.7, 1.1], (x, 6.6, 7.6), col, "Fabric"))
        out.append(fpart(F, f"PackTop{i}", [1.8, 1.1, 1.1], (x, 7.45, 7.6), col, "Fabric", shape="Cylinder"))
        out.append(fpart(F, f"PackFlap{i}", [1.0, 1.18, 1.18], (x, 7.47, 7.58), [c * 0.7 for c in col], "Fabric", shape="Cylinder"))
        out.append(ellip(f"PackPocket{i}", [1.1, 0.8, 0.45], F.p(x, 6.35, 6.98), [c * 0.8 for c in col], "Fabric", rot=F.r()))
    out.append(fpart(F, "BigPack", [2.2, 2.0, 1.3], (10.2, 1.4, 6.6), rgb(70, 160, 90), "Fabric"))
    out.append(fpart(F, "BigPackTop", [2.2, 1.3, 1.3], (10.2, 2.4, 6.6), rgb(50, 120, 65), "Fabric", shape="Cylinder"))
    # counter goodies
    out.append(fpart(F, "CounterDetector", [0.16, 2.6, 0.16], (-6, 4.9, 0.2), rgb(60, 60, 66), "Metal", lrot=angles(0, 0, 50)))
    out.append(fpart(F, "CounterCoil", [0.14, 1.2, 1.2], (-7.0, 4.0, 0.2), rgb(40, 170, 190), "SmoothPlastic", lrot=CYL_Y(), shape="Cylinder"))
    out.append(fpart(F, "Register", [1.6, 1.1, 1.1], (5.5, 4.45, 0.2), rgb(60, 70, 80), "Metal"))
    out.append(fpart(F, "RegisterScreen", [1.2, 0.5, 0.05], (5.5, 4.75, -0.37), rgb(140, 255, 200), "Neon"))
    out.append(fpart(F, "BoostJar", [1.2, 0.9, 0.9], (8, 4.5, 0.2), rgb(110, 230, 120), "Glass", lrot=CYL_Y(), shape="Cylinder", transparency=0.3))
    out.append(fpart(F, "BoostJarLid", [0.25, 1.0, 1.0], (8, 5.2, 0.2), rgb(255, 205, 90), "Metal", lrot=CYL_Y(), shape="Cylinder"))
    return out

def sell_props(F):
    out = appraiser_props(F)
    gold = rgb(255, 200, 60)
    for i in range(14):
        out.append(fpart(F, f"Pile{i}", [0.7, 0.7, 0.7], (-7 + (i % 5) * 0.5, 0.75 + (i // 5) * 0.4, 6.4 + (i % 3) * 0.4), gold, "Metal", shape="Ball"))
    out.append(fpart(F, "PriceBoard", [5, 3.2, 0.2], (5.5, 10.6, 8.1), rgb(40, 30, 25), "Slate",
                     children=[sign_gui("WE BUY\nTREASURE!", rgb(255, 220, 120), ppu=24)]))
    return out

SHOPS = [
    ("EquipmentShop", (-60, 0, 150), -90, "🛒 EQUIPMENT SHOP", rgb(40, 170, 190), equipment_props, 28, False,
     lambda F: npc(F, "EquipmentShop", "Marina", "Equipment Shop", "Browse Shop", SKIN["tan"], rgb(40, 170, 190), rgb(40, 170, 190), rgb(190, 170, 120), [
        ("Vest", [2.08, 1.7, 1.08], (0, 3.1, 0), rgb(25, 110, 125)),
        ("Apron", [1.7, 2.2, 0.1], (0, 2.3, -0.55), rgb(232, 214, 168), {"mat": "Fabric"}),
        ("ApronPocket", [1.1, 0.5, 0.06], (0, 2.0, -0.62), rgb(200, 180, 130), {"mat": "Fabric"}),
        ("HatCrown", [0.7, 1.4, 1.4], (0, 5.42, 0), rgb(232, 214, 168), {"rot": CYL_Y(), "shape": "Cylinder", "rig": "Head"}),
        ("HatBrim", [0.12, 2.3, 2.3], (0, 5.12, 0), rgb(232, 214, 168), {"rot": CYL_Y(), "shape": "Cylinder", "rig": "Head"}),
        ("HatBand", [0.2, 1.45, 1.45], (0, 5.25, 0), rgb(40, 170, 190), {"rot": CYL_Y(), "shape": "Cylinder", "rig": "Head"}),
        ("Ponytail", [0.5, 1.1, 0.5], (0, 4.4, 0.75), rgb(110, 60, 30), {"rig": "Head"}),
     ])),
    ("SellShop", (60, 0, 150), 90, "💰 SELL SHOP", rgb(230, 170, 40), sell_props, 22, True,
     lambda F: npc(F, "SellShop", "Captain Goldtooth", "Sell Shop", "Sell Treasures", SKIN["light"], rgb(160, 30, 40), rgb(160, 30, 40), rgb(30, 30, 35), [
        ("CoatTrim", [0.3, 2.02, 1.03], (0, 3, 0), rgb(255, 200, 60)),
        ("Belt", [2.05, 0.3, 1.05], (0, 2.2, 0), rgb(30, 25, 25)),
        ("Buckle", [0.45, 0.32, 0.1], (0, 2.2, -0.55), rgb(255, 200, 60), {"mat": "Metal"}),
        ("Eyepatch", [0.36, 0.3, 0.08], (0.26, 4.72, -0.64), rgb(20, 20, 20), {"rig": "Head"}),
        ("PatchStrap", [1.3, 0.08, 1.3], (0, 4.85, 0), rgb(20, 20, 20), {"rig": "Head"}),
        ("HatBase", [2.0, 0.3, 1.7], (0, 5.2, 0), rgb(25, 25, 30), {"rig": "Head", "mat": "Fabric"}),
        ("HatTop", [1.3, 0.5, 1.1], (0, 5.55, 0), rgb(25, 25, 30), {"rig": "Head", "mat": "Fabric"}),
        ("HatTrim", [2.05, 0.08, 1.75], (0, 5.37, 0), rgb(255, 200, 60), {"rig": "Head", "mat": "Metal"}),
        ("Beard", [1.05, 0.5, 0.3], (0, 4.22, -0.55), rgb(90, 50, 25), {"rig": "Head"}),
     ])),
]

shops = []
for (nm, c, yaw, title, accent, props, width, shelves, npc_fn) in SHOPS:
    shops.append(storefront(nm, list(c), yaw, title, accent, npc_fn, props, W=width, shelves=shelves))
hub.append(folder("Shops", shops))

def board(name, x, z, title, sub, color, action, obj, ui):
    F = Frame([x, 0, z], 0)
    return folder(name, [
        fpart(F, "PostL", [7, 0.7, 0.7], (-4.6, 3.5, 0), rgb(100, 70, 45), "Wood", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "PostR", [7, 0.7, 0.7], (4.6, 3.5, 0), rgb(100, 70, 45), "Wood", lrot=CYL_Y(), shape="Cylinder"),
        fpart(F, "CapL", [1, 1, 1], (-4.6, 7.2, 0), rgb(255, 205, 90), "Metal", shape="Ball"),
        fpart(F, "CapR", [1, 1, 1], (4.6, 7.2, 0), rgb(255, 205, 90), "Metal", shape="Ball"),
        fpart(F, "Roof", [11, 0.8, 0.8], (0, 8.75, 0), color, "WoodPlanks", shape="Cylinder"),
        fpart(F, "Board", [10, 4.6, 0.4], (0, 6.2, 0), color, "WoodPlanks", children=[sign_gui(title + "\n" + sub, rgb(255, 255, 255), ppu=24), prompt(action, obj, ui)]),
    ], "Model")

hub.append(board("QuestBoard", -22, 206, "📜 DAILY QUESTS", "3 new quests every day", rgb(200, 80, 70), "View quests", "Quest Board", "Quests"))
hub.append(board("TravelBoard", 22, 206, "🧭 TRAVEL", "Visit your unlocked beaches", rgb(60, 150, 100), "Travel", "Zone Map", "Travel"))

hub.append(folder("Fountain", [
    part("Basin", [2, 18, 18], [0, 1, 175], rgb(200, 195, 185), "Marble", rot=angles(0, 0, 90), shape="Cylinder"),
    part("Water", [0.4, 16, 16], [0, 2, 175], rgb(60, 170, 200), "Glass", rot=angles(0, 0, 90), shape="Cylinder", transparency=0.3, collide=False),
    part("Pillar", [7, 2.2, 2.2], [0, 4.5, 175], rgb(200, 195, 185), "Marble", rot=angles(0, 0, 90), shape="Cylinder"),
    part("Top", [1.6, 1.6, 1.6], [0, 8.6, 175], rgb(255, 210, 80), "Neon", shape="Ball"),
], "Model"))
for i, (x, z) in enumerate([(-70, 110), (70, 110), (-70, 220), (70, 220), (-30, 228), (30, 228)]):
    hub.append(palm(f"Palm{i}", x, z, random.uniform(14, 18)))
for i, (x, z) in enumerate([(-20, 150), (20, 150), (-20, 195), (20, 195)]):
    hub.append(folder(f"Lamp{i}", [
        part("Pole", [9, 0.5, 0.5], [x, 4.5, z], rgb(50, 50, 55), "Metal", rot=angles(0, 0, 90), shape="Cylinder"),
        part("Light", [1.3, 1.3, 1.3], [x, 9.4, z], rgb(255, 230, 160), "Neon", shape="Ball", children=[{"name": "Light", "className": "PointLight", "properties": {"Brightness": 1.2, "Range": 20, "Color": rgb(255, 220, 160)}}]),
    ], "Model"))
for i, (x, z, yaw) in enumerate([(-30, 160, 90), (30, 160, -90), (-30, 186, 90), (30, 186, -90)]):
    F = Frame([x, 0, z], yaw)
    hub.append(folder(f"Bench{i}", [
        fpart(F, "Seat", [5, 0.3, 1.4], (0, 1.5, 0), rgb(165, 118, 76), "WoodPlanks"),
        fpart(F, "Back", [5, 1.2, 0.25], (0, 2.4, 0.65), rgb(165, 118, 76), "WoodPlanks", lrot=angles(-10, 0, 0)),
        fpart(F, "LegL", [0.3, 1.5, 1.2], (-2.1, 0.75, 0.1), rgb(50, 50, 55), "Metal"),
        fpart(F, "LegR", [0.3, 1.5, 1.2], (2.1, 0.75, 0.1), rgb(50, 50, 55), "Metal"),
    ], "Model"))
    hub.append(folder(f"Planter{i}", [
        fpart(F, "Box", [2.6, 1.4, 2.6], (0, 0.7, -4.2), rgb(190, 110, 70), "Brick"),
        part("Flowers", [2.6, 2.6, 2.6], F.p(0, 2.0, -4.2), rgb(70, 150, 70), "Grass", shape="Ball"),
        part("Bloom1", [0.7, 0.7, 0.7], F.p(0.6, 3.1, -4.4), rgb(255, 120, 160), "SmoothPlastic", shape="Ball", collide=False),
        part("Bloom2", [0.7, 0.7, 0.7], F.p(-0.7, 2.9, -3.9), rgb(255, 210, 80), "SmoothPlastic", shape="Ball", collide=False),
    ], "Model"))
hub.append(sign("BeachSign", [12, 6, 100], [14, 4, 0.6], "⬇ BEACHES ⬇\nStart detecting here!", [0, 0, 1]))
hub.append(sign("StreetSign", [0, 6, 233], [16, 4, 0.6], "⬆ SHOP STREET ⬆\nVisit treasure shops!", [0, 0, -1]))

# leaderboards (facing the plaza = -Z)
boards = []
for i, key in enumerate(["Level", "Luck", "Found", "ShopValue"]):
    x = -57 + i * 38
    boards.append(part(key, [24, 18, 1], [x, 13, 224], rgb(16, 44, 66), "SmoothPlastic"))
    boards.append(part(key + "Post", [1.2, 3, 1.2], [x, 1.5, 224], rgb(80, 80, 90), "Metal"))
hub.append(folder("Leaderboards", boards))

# ---------------------------------------------------------------- shop street + plots
street = [
    part("StreetGround", [432, 6, 84], [0, -3, 271], rgb(120, 175, 95), "Grass"),
    part("Road", [432, 0.3, 16], [0, 0.15, 239], rgb(200, 185, 150), "Cobblestone"),
]

LAYOUT = []  # (index, type, shopLevel, kind, params)
def L(t, lvl, **kw): LAYOUT.append((len(LAYOUT) + 1, t, lvl, kw))
# Shop level 1 (6)
L("Pedestal", 1, fx=-4, fz=-4); L("Pedestal", 1, fx=4, fz=-4)
L("Shelf", 1, side=-1, z=-12, y=4); L("Shelf", 1, side=-1, z=-4, y=4); L("Shelf", 1, side=1, z=-12, y=4); L("Shelf", 1, side=1, z=-4, y=4)
# 2 (4)
L("Case", 2, fx=-12, fz=-4); L("Case", 2, fx=12, fz=-4); L("Shelf", 2, side=-1, z=4, y=4); L("Shelf", 2, side=1, z=4, y=4)
# 3 (6)
for x in (-10.5, -3.5, 3.5, 10.5): L("Wall", 3, wx=x, wy=6)
L("Case", 3, fx=-4, fz=4); L("Case", 3, fx=4, fz=4)
# 4 (8)
L("Shelf", 4, side=-1, z=12, y=4); L("Shelf", 4, side=1, z=12, y=4)
for side in (-1, 1):
    for z in (-12, -4): L("Shelf", 4, side=side, z=z, y=8.5)
L("Pedestal", 4, fx=-12, fz=4); L("Pedestal", 4, fx=12, fz=4)
# 5 (10)
L("Wall", 5, wx=-17.5, wy=6); L("Wall", 5, wx=17.5, wy=6)
for x in (-10.5, -3.5, 3.5, 10.5): L("Wall", 5, wx=x, wy=11.5)
for side in (-1, 1):
    for z in (4, 12): L("Shelf", 5, side=side, z=z, y=8.5)
# 6 (14)
L("Wall", 6, wx=-17.5, wy=11.5); L("Wall", 6, wx=17.5, wy=11.5)
for x in (-17, -11, 11, 17): L("Wall", 6, front=True, wx=x, wy=8)
L("Pedestal", 6, fx=-12, fz=-12); L("Case", 6, fx=-4, fz=-12); L("Case", 6, fx=4, fz=-12); L("Pedestal", 6, fx=12, fz=-12)
L("Case", 6, fx=-12, fz=12); L("Pedestal", 6, fx=-4, fz=12); L("Pedestal", 6, fx=4, fz=12); L("Case", 6, fx=12, fz=12)
assert len(LAYOUT) == 48, len(LAYOUT)
counts = {}
for _, _, lvl, _ in LAYOUT: counts[lvl] = counts.get(lvl, 0) + 1
assert [counts[i] for i in range(1, 7)] == [6, 4, 6, 8, 10, 14], counts

PLOT_Z = 275
GOLD = rgb(255, 205, 90)
VELVET = rgb(140, 30, 48)
STONE = rgb(222, 214, 198)

def oriented(name, size, origin, R, lpos, color, material="SmoothPlastic", lrot=IDENT, **kw):
    """A part placed in a rotated local frame (origin + rotation R)."""
    v = apply(R, list(lpos))
    return part(name, size, [origin[0] + v[0], origin[1] + v[1], origin[2] + v[2]], color, material, rot=matmul(R, lrot), **kw)

def light(brightness, rng, color=rgb(255, 214, 160)):
    return {"name": "Light", "className": "PointLight", "properties": {"Brightness": brightness, "Range": rng, "Color": color}}

# ---- display furniture: an invisible anchor (the slot) + the furniture as its children.
# PersonalShopService shows the furniture ONLY while a treasure stands on it.
def furniture(stype, origin, R, attrs):
    T = lambda name, size, lpos, color, material="SmoothPlastic", lrot=IDENT, role=None, **kw: oriented(
        name, size, origin, R, lpos, color, material, lrot=lrot, attrs=({"ThemeRole": role} if role else None), **kw)
    kids = []
    if stype == "Pedestal":
        anchor_size = [2.6, 3, 2.6]
        kids += [
            T("Plinth", [0.6, 3.4, 3.4], (0, -1.2, 0), rgb(160, 110, 70), "Wood", CYL_Y(), "Furniture", shape="Cylinder"),
            T("Column", [2.0, 2.0, 2.0], (0, -0.1, 0), rgb(160, 110, 70), "Wood", CYL_Y(), "Furniture", shape="Cylinder"),
            T("Ring", [0.18, 2.15, 2.15], (0, 0.55, 0), GOLD, "Metal", CYL_Y(), "Trim", shape="Cylinder", collide=False),
            T("Capital", [0.4, 2.9, 2.9], (0, 1.1, 0), GOLD, "Metal", CYL_Y(), "Trim", shape="Cylinder"),
            ellip("Cushion", [2.1, 0.5, 2.1], [origin[0], origin[1] + 1.45, origin[2]], VELVET, "Fabric", collide=False),
        ]
        collide = True
    elif stype == "Case":
        anchor_size = [3, 2.4, 3]
        kids += [
            T("Base", [2.4, 3.3, 3.3], (0, 0, 0), rgb(160, 110, 70), "Wood", CYL_Y(), "Furniture", shape="Cylinder"),
            T("TrimLow", [0.25, 3.5, 3.5], (0, -1.08, 0), GOLD, "Metal", CYL_Y(), "Trim", shape="Cylinder", collide=False),
            T("TrimHigh", [0.25, 3.5, 3.5], (0, 1.15, 0), GOLD, "Metal", CYL_Y(), "Trim", shape="Cylinder", collide=False),
            T("Glass", [3.0, 3.0, 3.0], (0, 2.7, 0), rgb(205, 232, 255), "Glass", CYL_Y(), shape="Cylinder", transparency=0.72, shadow=False),
            T("Cap", [0.35, 3.3, 3.3], (0, 4.35, 0), GOLD, "Metal", CYL_Y(), "Trim", shape="Cylinder", children=[light(1.1, 7, rgb(255, 240, 220))]),
            T("Finial", [0.6, 0.6, 0.6], (0, 4.75, 0), GOLD, "Metal", shape="Ball", collide=False),
        ]
        collide = True
    elif stype == "Shelf":
        anchor_size = [6, 0.4, 3]
        kids += [
            T("Board", [6, 0.35, 3], (0, 0, 0), rgb(160, 110, 70), "Wood", role="Furniture"),
            T("Lip", [6.1, 0.5, 0.5], (0, 0.05, -1.5), GOLD, "Metal", role="Trim", shape="Cylinder", collide=False),
            T("BracketL", [0.3, 1.4, 1.6], (-2.4, -0.9, 0.7), rgb(160, 110, 70), "Wood", angles(0, 0, 180), "Furniture", cls="WedgePart", collide=False),
            T("BracketR", [0.3, 1.4, 1.6], (2.4, -0.9, 0.7), rgb(160, 110, 70), "Wood", angles(0, 0, 180), "Furniture", cls="WedgePart", collide=False),
            T("StudL", [0.5, 0.5, 0.5], (-3.05, 0.05, -1.5), GOLD, "Metal", shape="Ball", collide=False),
            T("StudR", [0.5, 0.5, 0.5], (3.05, 0.05, -1.5), GOLD, "Metal", shape="Ball", collide=False),
        ]
        collide = False
    else:  # Wall plaque
        anchor_size = [4.5, 4.5, 0.4]
        kids += [
            T("Backing", [4.3, 4.3, 0.3], (0, 0, 0.05), rgb(160, 110, 70), "Wood", role="Furniture"),
            T("Velvet", [3.6, 3.6, 0.12], (0, 0, -0.15), VELVET, "Fabric", collide=False),
            T("FrameTop", [4.6, 0.4, 0.4], (0, 2.2, -0.12), GOLD, "Metal", role="Trim", shape="Cylinder", collide=False),
            T("FrameBottom", [4.6, 0.4, 0.4], (0, -2.2, -0.12), GOLD, "Metal", role="Trim", shape="Cylinder", collide=False),
            T("FrameLeft", [4.6, 0.4, 0.4], (-2.2, 0, -0.12), GOLD, "Metal", CYL_Y(), "Trim", shape="Cylinder", collide=False),
            T("FrameRight", [4.6, 0.4, 0.4], (2.2, 0, -0.12), GOLD, "Metal", CYL_Y(), "Trim", shape="Cylinder", collide=False),
            T("Lamp", [0.5, 0.5, 0.5], (0, 2.85, -0.45), rgb(255, 226, 160), "Neon", shape="Ball", collide=False, children=[light(0.8, 8)]),
        ]
        collide = False
    # children of the furniture that use shape=... via T need it set: handled by part() kwargs
    return part(attrs["Name"], anchor_size, origin, rgb(160, 110, 70), "Wood", rot=R, transparency=1, collide=collide, shadow=False,
                attrs={k: v for k, v in attrs.items() if k != "Name"}, children=kids)

def plot_model(n, px):
    pz = PLOT_Z
    def P(x, y, z): return [px + x, y, pz + z]
    def W(name, size, x, y, z, role, mat="WoodPlanks", color=rgb(240, 226, 196), **kw):
        return part(name, size, P(x, y, z), color, mat, attrs={"ThemeRole": role} if role else None, **kw)
    def C(name, length, dia, x, y, z, axis, color, mat="SmoothPlastic", role=None, **kw):
        rot = {"X": IDENT, "Y": CYL_Y(), "Z": CYL_Z()}[axis]
        return part(name, [length, dia, dia], P(x, y, z), color, mat, rot=rot, shape="Cylinder", attrs={"ThemeRole": role} if role else None, **kw)
    def B(name, dia, x, y, z, color, mat="SmoothPlastic", **kw):
        return part(name, [dia, dia, dia], P(x, y, z), color, mat, shape="Ball", **kw)

    H = 16
    structure = [
        part("Plinth", [47, 1.4, 47], P(0, -0.6, 0), STONE, "Slate"),
        W("BackWall", [44, H, 1], 0, 8.2, 21.5, "Wall"),
        W("LeftWall", [1, H, 44], -21.5, 8.2, 0, "Wall"),
        W("RightWall", [1, H, 44], 21.5, 8.2, 0, "Wall"),
        W("FrontLeft", [16, H, 1], -14, 8.2, -21.5, "Wall"),
        W("FrontRight", [16, H, 1], 14, 8.2, -21.5, "Wall"),
        # ceiling with a 14x14 opening in the middle (covered until the skylight upgrade)
        W("CeilingLeft", [15, 0.6, 44], -14.5, 16.4, 0, "Wall"),
        W("CeilingRight", [15, 0.6, 44], 14.5, 16.4, 0, "Wall"),
        W("CeilingFront", [14, 0.6, 15], 0, 16.4, -14.5, "Wall"),
        W("CeilingBack", [14, 0.6, 15], 0, 16.4, 14.5, "Wall"),
        # wainscot + chair rail inside
        W("WainscotBack", [42, 3.6, 0.4], 0, 2.0, 20.8, "Furniture", "Wood", rgb(160, 110, 70)),
        W("WainscotLeft", [0.4, 3.6, 42], -20.8, 2.0, 0, "Furniture", "Wood", rgb(160, 110, 70)),
        W("WainscotRight", [0.4, 3.6, 42], 20.8, 2.0, 0, "Furniture", "Wood", rgb(160, 110, 70)),
        W("WainscotFrontL", [14.5, 3.6, 0.4], -13.75, 2.0, -20.8, "Furniture", "Wood", rgb(160, 110, 70)),
        W("WainscotFrontR", [14.5, 3.6, 0.4], 13.75, 2.0, -20.8, "Furniture", "Wood", rgb(160, 110, 70)),
        C("RailBack", 42, 0.45, 0, 3.9, 20.6, "X", GOLD, "Metal", "Trim", collide=False),
        C("RailLeft", 42, 0.45, -20.6, 3.9, 0, "Z", GOLD, "Metal", "Trim", collide=False),
        C("RailRight", 42, 0.45, 20.6, 3.9, 0, "Z", GOLD, "Metal", "Trim", collide=False),
        # crown molding outside (rounded)
        C("CrownBack", 45, 1.0, 0, 16.3, 21.9, "X", rgb(70, 170, 200), "SmoothPlastic", "Trim"),
        C("CrownLeft", 45, 1.0, -21.9, 16.3, 0, "Z", rgb(70, 170, 200), "SmoothPlastic", "Trim"),
        C("CrownRight", 45, 1.0, 21.9, 16.3, 0, "Z", rgb(70, 170, 200), "SmoothPlastic", "Trim"),
        # front parapet with a rounded rail
        W("Parapet", [44, 2.4, 1.2], 0, 17.4, -21.5, "Wall"),
        C("ParapetRail", 45, 1.3, 0, 18.7, -21.5, "X", rgb(70, 170, 200), "SmoothPlastic", "Trim"),
        # bullnose entrance step
        C("Step", 13, 1.2, 0, 0.1, -22.6, "X", STONE, "Slate"),
    ]
    # arched entrance: voussoir ring around a 12-wide door, gold keystone on top
    N = 11
    for k in range(N):
        a = (k + 0.5) / N * 180
        r = 7.45
        x, y = math.cos(math.radians(a)) * r, 10 + math.sin(math.radians(a)) * r
        keystone = k == N // 2
        structure.append(part(f"Arch{k}", [3.0 if keystone else 2.5, 3.6 if keystone else 3.1, 2.0 if keystone else 1.6], P(x, y, -21.5),
                              GOLD if keystone else rgb(70, 170, 200), "Metal" if keystone else "SmoothPlastic",
                              rot=angles(0, 0, a - 90), attrs=None if keystone else {"ThemeRole": "Trim"}))
    # facade pilasters + rounded corner turrets with domed caps
    for x in (-9.4, 9.4):
        structure += [C(f"Pilaster{x}", H, 1.6, x, 8.2, -22.1, "Y", rgb(240, 226, 196), "WoodPlanks", "Wall"),
                      C(f"PilasterCap{x}", 0.5, 2.2, x, 16.1, -22.1, "Y", GOLD, "Metal", "Trim")]
    for x in (-22, 22):
        for z in (-22, 22):
            structure += [C(f"Turret{x}_{z}", 18.5, 3.4, x, 9.0, z, "Y", rgb(240, 226, 196), "WoodPlanks", "Wall"),
                          ellip(f"TurretDome{x}_{z}", [3.8, 3.2, 3.8], P(x, 18.6, z), rgb(70, 170, 200), attrs={"ThemeRole": "Trim"}),
                          B(f"TurretFinial{x}_{z}", 0.8, x, 20.4, z, GOLD, "Metal")]
    # display windows (glowing glass with rounded frames and a sill)
    for x in (-14.5, 14.5):
        structure += [
            part(f"Window{x}", [5.2, 6.4, 0.25], P(x, 8.2, -22.1), rgb(255, 228, 170), "Glass", transparency=0.25),
            C(f"WindowTop{x}", 5.8, 0.45, x, 11.45, -22.25, "X", GOLD, "Metal", "Trim", collide=False),
            C(f"WindowLeft{x}", 6.8, 0.45, x - 2.8, 8.2, -22.25, "Y", GOLD, "Metal", "Trim", collide=False),
            C(f"WindowRight{x}", 6.8, 0.45, x + 2.8, 8.2, -22.25, "Y", GOLD, "Metal", "Trim", collide=False),
            C(f"Sill{x}", 6.4, 0.7, x, 4.85, -22.4, "X", STONE, "Slate"),
        ]
    # pill-shaped sign above the arch with a brass rim and a crest
    sign_kids = [
        part("SignFrame", [22, 5.2, 0.3], P(0, 23.2, -21.9), GOLD, "Metal"),
        C("SignCapL", 0.6, 4.6, -11, 23.2, -22.15, "Z", rgb(90, 60, 40), "WoodPlanks"),
        C("SignCapR", 0.6, 4.6, 11, 23.2, -22.15, "Z", rgb(90, 60, 40), "WoodPlanks"),
        C("SignRimL", 0.3, 5.2, -11, 23.2, -21.9, "Z", GOLD, "Metal"),
        C("SignRimR", 0.3, 5.2, 11, 23.2, -21.9, "Z", GOLD, "Metal"),
        B("Crest", 1.4, 0, 26.4, -21.9, GOLD, "Metal"),
        part("SignPost", [0.6, 3.4, 0.6], P(0, 19.4, -21.6), GOLD, "Metal"),
    ]
    structure += sign_kids

    # interior: inlaid floor border, round rug, wall sconces
    interior = [
        part("BorderFront", [41, 0.06, 0.6], P(0, 0.23, -19.5), rgb(70, 170, 200), attrs={"ThemeRole": "Trim"}, collide=False),
        part("BorderBack", [41, 0.06, 0.6], P(0, 0.23, 19.5), rgb(70, 170, 200), attrs={"ThemeRole": "Trim"}, collide=False),
        part("BorderLeft", [0.6, 0.06, 41], P(-19.5, 0.23, 0), rgb(70, 170, 200), attrs={"ThemeRole": "Trim"}, collide=False),
        part("BorderRight", [0.6, 0.06, 41], P(19.5, 0.23, 0), rgb(70, 170, 200), attrs={"ThemeRole": "Trim"}, collide=False),
        C("RugEdge", 0.06, 18.8, 0, 0.23, 0, "Y", GOLD, "Metal", collide=False),
        C("Rug", 0.08, 18, 0, 0.25, 0, "Y", rgb(196, 52, 72), "Fabric", collide=False),
        C("RugBand", 0.09, 13.2, 0, 0.26, 0, "Y", rgb(236, 196, 120), "Fabric", collide=False),
        C("RugInner", 0.1, 12.4, 0, 0.27, 0, "Y", rgb(178, 40, 62), "Fabric", collide=False),
        C("RugMedallion", 0.11, 4.2, 0, 0.28, 0, "Y", rgb(240, 204, 120), "Fabric", collide=False),
    ]
    for x in (-20.6, 20.6):
        for z in (-10, 10):
            interior += [C(f"SconceArm{x}_{z}", 0.8, 0.3, x - math.copysign(0.4, x), 9.6, z, "X", GOLD, "Metal", collide=False),
                         B(f"Sconce{x}_{z}", 0.9, x - math.copysign(0.95, x), 9.9, z, rgb(255, 226, 160), "Neon", collide=False, children=[light(1.0, 20)])]

    # the Manage Shop desk, just inside the door on the left
    desk = folder("Desk", [
        part("Counter", [2.4, 3.2, 6], P(-14.5, 1.8, -17.5), rgb(160, 110, 70), "Wood", attrs={"ThemeRole": "Furniture"}),
        C("CounterNose", 6.2, 0.7, -13.3, 3.15, -17.5, "Z", GOLD, "Metal", "Trim"),
        part("CounterTop", [2.9, 0.25, 6.4], P(-14.5, 3.5, -17.5), rgb(70, 170, 200), attrs={"ThemeRole": "Trim"}),
        part("Ledger", [1.2, 0.25, 1.6], P(-14.4, 3.75, -18.4), rgb(245, 232, 200), "SmoothPlastic", rot=angles(0, 15, 0)),
        part("LedgerCover", [1.25, 0.08, 1.65], P(-14.4, 3.62, -18.4), VELVET, "Fabric", rot=angles(0, 15, 0)),
        B("Bell", 0.6, -14.5, 3.9, -16.2, GOLD, "Metal"),
        part("DeskSign", [0.25, 1.4, 4.2], P(-15.6, 5.6, -17.5), rgb(90, 60, 40), "WoodPlanks",
             children=[sign_gui("📒 MANAGE SHOP", rgb(255, 230, 160), face="Right", ppu=24)]),
        part("PromptAnchor", [1, 1, 1], P(-13.6, 4.6, -17.5), rgb(255, 255, 255), transparency=1, collide=False, query=False, shadow=False),
    ], "Model")

    # upgrade decor: appears once the owner's shop reaches ShopLevel (and HideAtLevel hides)
    def U(name, level, kids, hide=None):
        attrs = {"ShopLevel": level}
        if hide: attrs["HideAtLevel"] = hide
        return folder(name, kids, "Model", attrs=attrs)
    upgrades = [
        # until the skylight upgrade the opening is closed by a cover with a warm downlight,
        # so the middle of the room (rug, centre displays) is never left in the dark
        U("SkylightCover", 1, [W("Cover", [14, 0.6, 14], 0, 16.4, 0, "Wall", children=[
            {"name": "Downlight", "className": "SurfaceLight", "properties": {"Face": "Bottom", "Brightness": 1.6, "Range": 24, "Angle": 150, "Color": rgb(255, 228, 190)}},
        ])], hide=5),
    ]
    # L2 Seaside Shack: striped awnings over the windows + flower planters
    awn = []
    for x in (-14.5, 14.5):
        for i in range(5):
            col = rgb(255, 255, 255) if i % 2 else rgb(70, 170, 200)
            awn.append(part(f"Awning{x}_{i}", [1.3, 0.2, 2.6], P(x - 2.6 + i * 1.3, 12.3, -23.0), col, "Fabric", rot=angles(-22, 0, 0), collide=False))
            awn.append(ellip(f"Scallop{x}_{i}", [1.25, 0.8, 0.2], P(x - 2.6 + i * 1.3, 11.6, -24.2), col, "Fabric", collide=False))
        awn += [C(f"Planter{x}", 6, 1.3, x, 4.1, -22.9, "X", rgb(190, 110, 70), "Slate"),
                ellip(f"Hedge{x}", [6, 1.2, 1.2], P(x, 4.9, -22.9), rgb(70, 150, 70), "Grass", collide=False)]
        for j, c in enumerate([rgb(255, 120, 150), rgb(255, 220, 90), rgb(180, 120, 255), rgb(255, 150, 90)]):
            awn.append(B(f"Flower{x}_{j}", 0.5, x - 2.1 + j * 1.4, 5.5, -23.2, c, collide=False))
    upgrades.append(U("Awnings", 2, awn))
    # L3 Curio Boutique: marble entrance columns + brass lanterns by the door
    cols = []
    for x in (-10.4, 10.4):
        cols += [C(f"ColBase{x}", 0.8, 2.6, x, 0.4, -24.6, "Y", STONE, "Marble"),
                 C(f"ColShaft{x}", 12.2, 1.7, x, 6.9, -24.6, "Y", STONE, "Marble"),
                 C(f"ColCapital{x}", 0.9, 2.6, x, 13.4, -24.6, "Y", STONE, "Marble"),
                 C(f"LanternArm{x}", 2.2, 0.25, x * 0.62, 10.4, -23.0, "Z", GOLD, "Metal", collide=False),
                 ellip(f"Lantern{x}", [0.9, 1.2, 0.9], P(x * 0.62, 9.7, -24.0), rgb(255, 226, 160), "Neon", collide=False, children=[light(1.0, 14)]),
                 C(f"LanternCap{x}", 0.3, 1.0, x * 0.62, 10.35, -24.0, "Y", GOLD, "Metal", collide=False)]
    upgrades.append(U("Columns", 3, cols))
    # L4 Treasure Gallery: pendant lamps + velvet runner from the door
    lamps = [part("Runner", [5, 0.08, 11.5], P(0, 0.26, -14.5), VELVET, "Fabric", collide=False),
             part("RunnerEdgeL", [0.3, 0.09, 11.5], P(-2.55, 0.27, -14.5), GOLD, "Metal", collide=False),
             part("RunnerEdgeR", [0.3, 0.09, 11.5], P(2.55, 0.27, -14.5), GOLD, "Metal", collide=False)]
    for x, z in ((-11, -11), (11, -11), (-11, 11), (11, 11)):
        lamps += [C(f"Cord{x}_{z}", 3.6, 0.12, x, 14.3, z, "Y", rgb(40, 40, 45), collide=False),
                  C(f"Shade{x}_{z}", 0.7, 1.8, x, 12.4, z, "Y", GOLD, "Metal", collide=False),
                  B(f"Bulb{x}_{z}", 1.1, x, 11.8, z, rgb(255, 230, 170), "Neon", collide=False, children=[light(1.2, 18)])]
    upgrades.append(U("PendantLamps", 4, lamps))
    # L5 Maritime Museum: glass lantern skylight + banners on the facade
    sky = [part("SkyGlass", [14, 0.3, 14], P(0, 19.4, 0), rgb(200, 230, 255), "Glass", transparency=0.55)]
    for nm, size, pos in (("SkyN", [14, 2.8, 0.3], (0, 18.0, 7)), ("SkyS", [14, 2.8, 0.3], (0, 18.0, -7)),
                          ("SkyE", [0.3, 2.8, 14], (7, 18.0, 0)), ("SkyW", [0.3, 2.8, 14], (-7, 18.0, 0))):
        sky.append(part(nm, size, P(*pos), rgb(200, 230, 255), "Glass", transparency=0.55))
    for x in (-7, 7):
        sky.append(C(f"SkyBeamX{x}", 14.4, 0.4, x, 19.5, 0, "Z", GOLD, "Metal", collide=False))
        sky.append(C(f"SkyBeamZ{x}", 14.4, 0.4, 0, 19.5, x, "X", GOLD, "Metal", collide=False))
    for x in (-18.4, 18.4):
        sky += [part(f"Banner{x}", [2.4, 6.5, 0.12], P(x, 11.6, -22.2), rgb(70, 170, 200), "Fabric", attrs={"ThemeRole": "Trim"}, collide=False),
                C(f"BannerRod{x}", 3.0, 0.3, x, 15.0, -22.3, "X", GOLD, "Metal", collide=False),
                part(f"BannerTip{x}", [2.4, 1.2, 0.12], P(x, 7.75, -22.2), rgb(70, 170, 200), "Fabric", cls="WedgePart",
                     rot=angles(0, 0, 180), attrs={"ThemeRole": "Trim"}, collide=False)]
    upgrades.append(U("Skylight", 5, sky))
    # L6 Treasure Palace: golden statues, red carpet outside, crystal chandelier inside
    palace = [part("Carpet", [6, 0.1, 6.5], P(0, 0.25, -25.6), VELVET, "Fabric", collide=False),
              part("CarpetEdgeL", [0.35, 0.11, 6.5], P(-3.1, 0.26, -25.6), GOLD, "Metal", collide=False),
              part("CarpetEdgeR", [0.35, 0.11, 6.5], P(3.1, 0.26, -25.6), GOLD, "Metal", collide=False)]
    for x in (-15.8, 15.8):
        palace += [C(f"StatuePlinth{x}", 1.4, 3.0, x, 0.7, -25.5, "Y", STONE, "Marble"),
                   C(f"StatueBody{x}", 3.4, 1.5, x, 3.1, -25.5, "Y", rgb(255, 200, 60), "Metal"),
                   ellip(f"StatueChest{x}", [2.0, 1.4, 1.4], P(x, 4.4, -25.5), rgb(255, 200, 60), "Metal"),
                   B(f"StatueHead{x}", 1.3, x, 5.6, -25.5, rgb(255, 200, 60), "Metal"),
                   C(f"StatueCrown{x}", 0.5, 1.2, x, 6.35, -25.5, "Y", rgb(255, 230, 120), "Metal")]
    chandelier = [C("ChandChain", 4.0, 0.15, 0, 17.4, 0, "Y", GOLD, "Metal", collide=False),
                  B("ChandCore", 1.4, 0, 14.8, 0, rgb(255, 240, 200), "Neon", collide=False, children=[light(2.2, 26, rgb(255, 236, 200))])]
    for k in range(8):
        a = math.radians(k * 45)
        x, z = math.cos(a) * 2.2, math.sin(a) * 2.2
        chandelier += [part(f"ChandArm{k}", [1.8, 0.18, 0.18], P(x * 0.6, 15.0, z * 0.6), GOLD, "Metal", rot=angles(0, -k * 45, 0), collide=False),
                       B(f"Crystal{k}", 0.55, x, 14.4, z, rgb(220, 240, 255), "Glass", transparency=0.15, collide=False)]
    palace += chandelier
    upgrades.append(U("Palace", 6, palace))

    kids = [
        part("Floor", [44, 1, 44], P(0, -0.3, 0), rgb(196, 150, 100), "WoodPlanks", attrs={"ThemeRole": "Floor"}),
        folder("Structure", structure),
        folder("Interior", interior),
        desk,
        folder("Upgrades", upgrades),
        part("Sign", [22, 4.6, 0.6], P(0, 23.2, -22.4), rgb(90, 60, 40), "WoodPlanks"),
        part("Entrance", [4, 1, 4], P(0, 2, -30), rgb(255, 255, 255), rot=look_dir([0, 0, 1]), transparency=1, collide=False, query=False, shadow=False),
    ]
    slots = []
    for idx, stype, lvl, kw in LAYOUT:
        attrs = {"Name": "Slot%02d" % idx, "SlotIndex": idx, "SlotType": stype, "ShopLevel": lvl}
        if stype == "Shelf":
            side = kw["side"]
            slots.append(furniture(stype, P(side * 20.0, kw["y"], kw["z"]), look_dir([-side, 0, 0]), attrs))
        elif stype == "Wall":
            if kw.get("front"):
                slots.append(furniture(stype, P(kw["wx"], kw["wy"], -21.1), look_dir([0, 0, 1]), attrs))
            else:
                slots.append(furniture(stype, P(kw["wx"], kw["wy"], 21.1), look_dir([0, 0, -1]), attrs))
        elif stype == "Pedestal":
            slots.append(furniture(stype, P(kw["fx"], 1.7, kw["fz"]), look_dir([0, 0, -1]), attrs))
        elif stype == "Case":
            slots.append(furniture(stype, P(kw["fx"], 1.4, kw["fz"]), look_dir([0, 0, -1]), attrs))
    kids.append(folder("Slots", slots))
    kids.append(folder("Displays", []))
    return folder(f"Plot{n}", kids, "Model", attrs={"PlotIndex": n, "OwnerUserId": 0})

plots = [plot_model(n + 1, -175 + n * 50) for n in range(8)]

# ---------------------------------------------------------------- assemble
sea = part("SeaPreview", [1440, 12, 440], [510, -6.5, -230], rgb(40, 150, 190), "SmoothPlastic", transparency=0.35, collide=False, query=False, shadow=False)
# "at base" = inside this box (plaza, NPC shops, shop street, shop plots) - used by the server
town = part("Town", [464, 120, 228], [0, 30, 206], rgb(255, 255, 255), transparency=1, collide=False, query=False, shadow=False)
map_model = {"className": "Folder", "children": [
    folder("Zones", zones_children),
    folder("Hub", hub),
    folder("ShopStreet", street),
    folder("ShopPlots", plots),
    folder("Boundaries", bounds),
    sea,
    town,
]}
json.dump(map_model, open("map/Map.model.json", "w"), indent=0)

def count(n): return 1 + sum(count(c) for c in n.get("children", []))
print("instances:", count(map_model))
