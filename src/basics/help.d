module basics.help;

import std.array;
import std.algorithm : find;
import std.conv;
import std.math;
import std.string;
import std.uni;
import std.utf;

pure int even(in int x) { return x - (x & 1); }

unittest {
    assert (even( 5) ==  4);
    assert (even(-5) == -6);
    assert (even(-6) == -6);
}



// mod function that always returns values in 0 .. modulo
pure int positiveMod(in int nr, in int modulo)
{
    if (modulo <= 0) return 0;
    immutable int normalMod = nr % modulo;
    if (normalMod >= 0) return normalMod;
    else                return normalMod + modulo;
}

unittest {
    assert (          (-5 % 3) == -2);
    assert (positiveMod(-5, 3) ==  1);
    assert (positiveMod( 5, 3) ==  2);
}



// Phobos has rounding, but tiebreaks only either to the even integer,
// or away from zero. I want to tiebreak to the larger integer.
pure int
roundInt(F)(in F f)
    if (is (F : float))
{
    return (f + 0.5f).floor.to!int;
}



string
backspace(in string str)
{
    if (str.empty) return null;
    else return str[0 .. str.length - std.utf.strideBack(str, str.length)];
}

unittest {
    assert (backspace("hello") == "hell");
    assert (backspace("") == "");
}



pure nothrow string
escapeStringForFilename(string unescapedRemainder)
{
    // remove all special characters except these few
    string allowed = "_-";
    char[] pruned;
    try while (unescapedRemainder.length > 0) {
        dchar c = std.utf.decodeFront(unescapedRemainder);
        if (c.isAlpha || c.isMark || c.isNumber || allowed.find(c) != null)
            pruned.encode(c);
    }
    catch (Exception) { }
    return pruned.idup;
}

unittest {
    assert (escapeStringForFilename("hallo") == "hallo");
    assert (escapeStringForFilename("don't/use/dirs") == "dontusedirs");
    assert (escapeStringForFilename("Ä ö Ü ß") == "ÄöÜß");
    assert (escapeStringForFilename(":D ^_^ :-|") == "D_-");
    assert (escapeStringForFilename(".,123") == "123");
    assert (escapeStringForFilename("リッくス") == "リッくス");
}



pure nothrow int
len(T)(in T[] arr)
{
    // Arrays with more than 2^^31 entries are bugs. Let's not call to!int, but
    // chop off the big bits of the size_t (= uint or ulong). It's the same
    // effect, but doesn't check if it has to throw.
    return arr.length & 0x7F_FF_FF_FF;
}



void
destroyArray(T)(ref T arr)
{
    foreach (ref var; arr) {
        destroy(var);
        var = null;
    }
    destroy(arr);
    arr = null;
}



@property const(T)[]
dupConst(T)(in const(T[]) arr)
{
    const(T)[] dupped;
    foreach (ref const(T) element; arr)
        dupped ~= element;
    return dupped;
}



@property T[]
clone(T)(in const(T)[] arr)
    if (is (T == class) || is (T == struct))
{
    static if (is (T == struct))
        return arr.dup;
    else {
        T[] ret;
        ret.length = arr.length;
        for (int i = 0; i < arr.length; ++i)
            ret[i] = arr[i].clone();
        return ret;
    }
}
