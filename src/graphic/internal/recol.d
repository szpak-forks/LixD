module graphic.internal.recol;

import std.string;

import basics.alleg5;
import file.filename;
import graphic.color;
import graphic.cutbit;
import graphic.internal.getters;
import graphic.internal.names;
import graphic.internal.vars;
import hardware.tharsis;

package:

void eidrecol(Cutbit cutbit, int magicnr)
{
    // don't do anything for magicnr == magicnrSpritesheets. This function
    // is about GUI recoloring, not player color recoloring. All GUI portions
    // of the spritesheets have been moved to the skill buttons in 2015-10.
    assert (magicnr != magicnrSpritesheets);

    makeColorDicts();
    version (tharsisprofiling)
        auto zone = Zone(profiler, "eidrecol magicnr = %d".format(magicnr));
    if (! cutbit || ! cutbit.valid)
        return;
    Albit bitmap = cutbit.albit;

    if (magicnr == 0) {
        auto region = al_lock_bitmap(bitmap,
         ALLEGRO_PIXEL_FORMAT.ALLEGRO_PIXEL_FORMAT_ANY,
         ALLEGRO_LOCK_READWRITE);
        assert (region, "can't lock bitmap despite magicnr == 0");
    }
    scope (exit)
        if (magicnr == 0)
            al_unlock_bitmap(bitmap);

    auto targetBitmap = TargetBitmap(bitmap);
    immutable bmp_yl = al_get_bitmap_height(bitmap);
    if (magicnr == 0)
        for (int y = 0; y < bmp_yl; ++y)
            applyToRow(y > cutbit.yl ? dictGuiLight
                                     : dictGuiNormal, bitmap, y);
    else if (magicnr == magicnrSkillButtonIcons) {
        recolorAllShadows(bitmap);
        for (int y = cutbit.yl + 1; y < bmp_yl; ++y) // only row 1 (of 0, 1)
            dictGuiNormalNoShadow.applyToRow(bitmap, y);
    }
    else if (magicnr == magicnrPanelInfoIcons) {
        recolorAllShadows(bitmap);
        for (int y = cutbit.yl + 1; y < 2 * (cutbit.yl + 1); ++y)
            dictGuiNormalNoShadow.applyToRow(bitmap, y);
    }
}

Cutbit lockThenRecolor(int magicnr)(
    Cutbit sourceCb,
    in Style st
) {
    // We assume sourceCb to be unlocked, and are going to lock it
    // in this function.
    if (! sourceCb || ! sourceCb.valid)
        return nullCutbit;
    Albit lix = sourceCb.albit;
    assert (lix);
    immutable int lixXl = al_get_bitmap_width (lix);
    immutable int lixYl = al_get_bitmap_height(lix);
    immutable colBreak  = al_get_pixel(lix, lixXl - 1, 0);

    void recolorTargetForStyle()
    {
        version (tharsisprofiling)
            auto zone = Zone(profiler, format("recolor-one-bmp-%d", magicnr));
        Alcol[Alcol] recolArray = generateRecolArray(st);

        Y_LOOP: for (int y = 0; y < lixYl; y++) {
            static if (magicnr == magicnrSkillButtonIcons) {
                // The skill button icons have two rows: the first has the
                // skills in player colors, the second has them greyed out.
                // Ignore the second row here.
                if (y >= sourceCb.yl + 1)
                    break Y_LOOP;
            }
            else static if (magicnr == magicnrPanelInfoIcons) {
                // Skip all x pixels in the second row of the little icons.
                if (y >= sourceCb.yl + 1 && y < 2 * (sourceCb.yl + 1))
                    continue Y_LOOP;
            }
            X_LOOP: for (int x = 0; x < lixXl; x++) {
                immutable Alcol col = al_get_pixel(lix, x, y);
                static if (magicnr == magicnrSpritesheets) {
                    // on two consecutive pixels with colBreak, skip for speed
                    if (col == colBreak && x < lixXl - 1
                        && al_get_pixel(lix, x+1, y) == colBreak)
                        // bad:  immediately begin next row, because
                        //       we may have separating colBreak-colored
                        //       frames in the file.
                        // good: immediately begin next frame. We have already
                        //       advanced into the frame by 1 pixel, as we have
                        //       seen two
                        x += sourceCb.xl;
                }
                if (Alcol* colPtr = (col in recolArray))
                    al_put_pixel(x, y, *colPtr);
            }
        }
    }
    // end function recolorForStyle

    // now invoke the above code on the single wanted Lix style
    Cutbit targetCb = new Cutbit(sourceCb);
    version (tharsisprofiling)
        auto zone = Zone(profiler, format("recolor-one-foreach-%d", magicnr));
    auto lock  = LockReadOnly(lix);
    auto lock2 = LockReadWrite(targetCb.albit); // see [1] at end of function
    auto targetBitmap = TargetBitmap(targetCb.albit);

    recolorTargetForStyle();
    if (magicnr == magicnrSpritesheets && ! eyesOnSpritesheet)
        findEyesOnSpritesheet(sourceCb, colBreak);

    // eidrecol invoked with magicnr != 0 expects already-locked bitmap
    static if (magicnr != magicnrSpritesheets)
        eidrecol(targetCb, magicnr);
    return targetCb;

    /* [1]: Why do we lock targetCb.albit at all?
     * I have no idea why we are doing this (2016-03). recolorTargetForStyle
     * runs extremely slowly if we don't lock targetCb.albit, even though we
     * only write to it. Speculation: al_put_pixel is slow on RAM bitmaps.
     *
     * We would have to lock targetCb.albit as read-write when going into
     * the eidrecol function. So we don't lose anything by locking it earlier.
     */
}

void makeAlcol3DforStyle(in Style st)
{
    assert (! alcol3DforStyles[st].isValid, "don't initialize twice");
    // Initialize with a default, so we don't query the image several times
    // if the image fails to exist
    with (alcol3DforStyles[st])
        l = m = d = color.white;
    Cutbit rclCb = InternalImage.styleRecol.getInternalMutable;
    assert (rclCb);
    Albit recol = rclCb.albit;
    if (recol is null || al_get_bitmap_height(recol) < st - 1) {
        logRecoloringError(recol, 0, st);
        return;
    }
    if (al_get_bitmap_width(recol) < 8 + 1) {
        logRecoloringError(recol, 8, st);
        return;
    }
    auto lock = LockReadOnly(recol);
    with (alcol3DforStyles[st]) {
        l = al_get_pixel(recol, 6, st + 1); // st + 1 because row 0 has the
        m = al_get_pixel(recol, 7, st + 1); // colors from the source file,
        d = al_get_pixel(recol, 8, st + 1); // they don't belong to any style
    }
}



// ############################################################################

private:

Alcol[Alcol] dictGuiLight, dictGuiNormal, dictGuiNormalNoShadow;

void makeColorDicts()
{
    // I don't dare to make these at compile time, unsure whether Alcol's
    // bitwise interpretation depends on color mode chosen by Allegro 5
    if (dictGuiLight != null)
        return;
    dictGuiLight[color.black]      = color.transp;
    dictGuiLight[color.guiFileSha] = color.guiSha;
    dictGuiLight[color.guiFileD]   = color.guiPicOn.d;
    dictGuiLight[color.guiFileM]   = color.guiPicOn.m;
    dictGuiLight[color.guiFileL]   = color.guiPicOn.l;
    dictGuiNormal[color.black]      = color.transp;
    dictGuiNormal[color.guiFileSha] = color.guiSha;
    dictGuiNormal[color.guiFileD]   = color.guiPic.d;
    dictGuiNormal[color.guiFileM]   = color.guiPic.m;
    dictGuiNormal[color.guiFileL]   = color.guiPic.l;
    dictGuiNormalNoShadow = dictGuiNormal.dup;
    dictGuiNormalNoShadow.remove(color.guiFileSha);
}

void applyToAllRows(Alcol[Alcol] dict, Albit bitmap)
{
    foreach (int row; 0 .. al_get_bitmap_height(bitmap))
        dict.applyToRow(bitmap, row);
}

void applyToRow(Alcol[Alcol] dict, Albit bitmap, int row)
{
    // We assume the bitmap to be locked for speed!
    foreach (int x; 0 .. al_get_bitmap_width(bitmap)) {
        immutable Alcol c = al_get_pixel(bitmap, x, row);
        if (auto newCol = c in dict)
            al_put_pixel(x, row, *newCol);
    }
}

void recolorAllShadows(Albit bitmap)
{
    foreach (int y; 0 .. al_get_bitmap_height(bitmap))
        foreach (int x; 0 .. al_get_bitmap_width(bitmap)) {
            immutable Alcol c = al_get_pixel(bitmap, x, y);
            if (c == color.guiFileSha)
                al_put_pixel(x, y, color.guiSha);
        }
}

Alcol[Alcol] generateRecolArray(in Style st)
{
    Cutbit rclCb = InternalImage.styleRecol.getInternalMutable;
    assert (rclCb);
    Albit recol = rclCb.albit;
    if (recol is null) {
        logRecoloringError(null, 0, st);
        return null;
    }
    auto lock = LockReadOnly(recol);
    Alcol[Alcol] recolArray;
    if (st < al_get_bitmap_height(recol) - 1)
        foreach (x; 0 .. al_get_bitmap_width(recol))
            // The first row (y == 0) contains the source pixels. First style
            // (garden) is at y == 1. Thus, target colors are at y == st + 1.
            recolArray[al_get_pixel(recol, x, 0)] =
                       al_get_pixel(recol, x, st + 1);
    else
        logRecoloringError(recol, 0, st);
    return recolArray;
}

void logRecoloringError(
    Albit recol, // if null, image doesn't exist, say that
    in int x, // if > 0, then we tried to read that pixel and it doesn't exist
    in Style st,
) {
    import file.log;
    import std.conv;
    logf("Error with the recoloring map %s:",
        InternalImage.styleRecol.toBasename);
    if (recol is null) {
        logf("    -> File doesn't exist or format not supported.");
        return;
    }
    if (st >= al_get_bitmap_height(recol) - 1)
        logf("    -> Height is %d, but for style `%s', we need height >= %d.",
            al_get_bitmap_height(recol), styleToString(st), st + 1);
    if (x > 0)
        logf("    -> Width is %d, but we need width >= %d.",
            al_get_bitmap_width(recol), x + 1, ".");
}

void findEyesOnSpritesheet(in Cutbit spri, in Alcol colBreak)
{
    // We assume spri's Albit to be locked already!
    // spri are the unrecolored sprites directly loaded from file.
    assert (spri);
    assert (! eyesOnSpritesheet, "don't find the eyes twice");

    version (tharsisprofiling) {
        import hardware.tharsis;
        auto zo = Zone(profiler, "eye matrix creation");
    }
    assert (spri && spri.xfs > 1 && spri.yfs > 1, "need Lix sprites for eyes");
    eyesOnSpritesheet = new typeof(eyesOnSpritesheet)(spri.xfs, spri.yfs);
    immutable eyeCol = color.lixFileEye;

    foreach (int yf; 0 .. spri.yfs)
        FRAME_LOOP: foreach (int xf; 0 .. spri.xfs) {
            foreach (int y; 0 .. spri.yl)
                foreach (int x; 0 .. spri.xl) {
                    Alcol c = spri.get_pixel(xf, yf, Point(x, y));
                    if (c == eyeCol) {
                        // found one eye. Maybe use average of two eyes?
                        if (x + 2 < spri.xl && spri.get_pixel(xf, yf,
                                               Point(x + 2, y)) == eyeCol)
                            eyesOnSpritesheet.set(xf, yf, Point(x + 1, y));
                        else
                            eyesOnSpritesheet.set(xf, yf, Point(x, y));
                        continue FRAME_LOOP;
                    }
                    else if (c == colBreak)
                        continue FRAME_LOOP;
                }
            // We didn't find an eye.
            // Sometimes, the lix covers her eyes with her hands.
            assert (eyesOnSpritesheet.get(xf, yf) == Point.init);
            if (xf > 0) {
                // Use the previous frame's eye position then.
                eyesOnSpritesheet.set(xf, yf, eyesOnSpritesheet.get(xf-1, yf));
            }
            else {
                // The miner has this problem in the first frame. Hardcode:
                eyesOnSpritesheet.set(xf, yf, Point(17, 13));
            }
        }
}
