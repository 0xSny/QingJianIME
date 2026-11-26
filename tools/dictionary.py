"""Compile a syllable trie, ranked homophones and corpus transitions for mmap."""
import collections
import math
import pathlib
import re
import struct
import urllib.request
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "Keyboard/Resources"
ICE = "https://raw.githubusercontent.com/iDvel/rime-ice/927e1cf1d3eeb9bf4be85e3f684dba4dd485b6f6/"
UD = "https://raw.githubusercontent.com/UniversalDependencies/UD_Chinese-GSDSimp/b79a1c2f7ba7f9b264808d91c6886a67b7f847a3/"
FINALS = dict(zip("iu ei uan ue ve un uo ie uai ing ai en eng iang uang ang an ong iong ou ia ua ao ui in iao ian".split(),
                  "q w r t t y o p k k d f g l l h j s s z x x c v b n m".split()))

def fetch(url):
    cache = ROOT / ".cache" / url.rsplit("/", 1)[1]
    cache.parent.mkdir(exist_ok=True)
    if not cache.exists():
        data = urllib.request.urlopen(url, timeout=120).read()
        cache.write_bytes(data)
    return cache.read_text(encoding="utf-8-sig")

def fly(s):
    match = re.fullmatch(r"(zh|ch|sh|[bpmfdtnlgkhjqxrzcsyw]?)([a-z]+)", s)
    if not match:
        return ""
    head, tail = match.groups()
    if not head:
        return s * 2 if len(s) == 1 else s if len(s) == 2 else s[0] + FINALS.get(s, "")
    if tail not in FINALS and tail not in ("a","o","e","i","u","v"):
        return ""
    return {"zh":"v","ch":"i","sh":"u"}.get(head,head) + FINALS.get(tail,tail)

def rows(name):
    for line in fetch(ICE + "cn_dicts/" + name + ".dict.yaml").splitlines():
        parts = line.split("#")[0].strip().split("\t")
        if len(parts) < 2 or not re.fullmatch("[一-龥]+", parts[0]):
            continue
        try:
            # GB2312 excludes rare extensions and non-standard glyphs.
            parts[0].encode("gb2312")
            freq = max(1, int(parts[2])) if len(parts) > 2 else 1
        except (UnicodeError, ValueError):
            continue
        sounds = tuple(parts[1].split())
        if len(parts[0]) == len(sounds):
            yield parts[0], sounds, freq

def compile_dictionary():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = {}
    for word, sounds, freq in rows("8105"):
        if len(word) == 1 and re.fullmatch("[a-z]+",sounds[0]) and len(fly(sounds[0])) == 2:
            entries[word,sounds] = freq
    valid = {s[0] for _, s in entries}
    for word, sounds, freq in rows("base"):
        if all(s in valid for s in sounds):
            entries[word,sounds] = max(entries.get((word,sounds),0),freq)
    syllables = sorted(valid)
    ids = {s:i for i,s in enumerate(syllables)}
    pool = bytearray(b"\0")
    offsets = {}
    def intern(s):
        if s not in offsets:
            offsets[s] = len(pool)
            pool.extend(s.encode() + b"\0")
        return offsets[s]
    syl = b"".join(struct.pack("<II",intern(s),intern(fly(s))) for s in syllables)
    children, values = [{}], [[]]
    for (word,sounds),freq in entries.items():
        node = 0
        for s in sounds:
            sid = ids[s]
            if sid not in children[node]:
                children[node][sid] = len(children)
                children.append({})
                values.append([])
            node = children[node][sid]
        values[node].append((freq,word," ".join(sounds)))
    nodes, edges, words = bytearray(),bytearray(),bytearray()
    for child, vals in zip(children,values):
        nodes.extend(struct.pack("<IIII",len(edges)//8,len(child),len(words)//12,len(vals)))
        for sid,target in sorted(child.items()):
            edges.extend(struct.pack("<II",sid,target))
        for freq,word,reading in sorted(vals,reverse=True):
            words.extend(struct.pack("<IIf",intern(word),intern(reading),math.log1p(freq)))
    pairs = collections.Counter()
    prev = ""
    for line in fetch(UD+"zh_gsdsimp-ud-train.conllu").splitlines():
        cols = line.split("\t")
        if len(cols) != 10 or not cols[0].isdigit():
            prev = ""
            continue
        word = cols[1]
        if prev in offsets and word in offsets:
            pairs[prev,offsets[word]] += 1
        prev = word
    bigrams = b"".join(struct.pack("<III",offsets[a],b,c) for (a,b),c in sorted(pairs.items()))
    sections = [syl,nodes,edges,words,bigrams,pool]
    payload = b"".join(sections)
    header = struct.pack("<4s9I",b"QJ17",1,zlib.crc32(payload),*map(len,sections),len(payload))
    (OUT/"lex.bin").write_bytes(header+payload)
    assert len(entries)>50000 and len(pairs)>1000
    (OUT/"Credits.txt").write_text((ROOT/"NOTICE.md").read_text(encoding="utf8")+"\n\n".replace(chr(10), chr(10))+(ROOT/"LICENSE").read_text(encoding="utf8"),encoding="utf8")
    print(len(entries),"entries;",len(pairs),"transitions;",len(payload),"bytes")

if __name__ == "__main__":
    compile_dictionary()
