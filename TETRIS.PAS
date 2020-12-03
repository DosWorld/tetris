{
 MIT License

Copyright (c) 2020 Viacheslav Komenda

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
}
{$I-,R-,S-,F-,Q-,G-,A+,E-,D-,L-}
{$M 1024,0,0}
procedure Locate(x, y : integer);assembler;
asm
        push       ds
        mov        ax, word ptr [seg0040]
        mov        ds, ax
        mov        bh, byte ptr [$0062]
        pop        ds

        mov        dl, byte ptr [x]
        mov        dh, byte ptr [y]
        mov        ah, 2
        int        $10
end;

procedure Text40x25Mode;assembler;
asm
        mov        ax, 1
        int        $10
end;

procedure TextMode;assembler;
asm
        mov        ax, 3
        int        $10
end;

function GetKey:word;assembler;
asm
        xor        ax, ax
        int        $16
end;

function HasKey:boolean;assembler;
asm
        mov        ah, 1
        int        $16
        jnz        @has
        xor        al, al
        jmp        @end
@has:
        mov        al, 1
@end:
end;

procedure sound(hz : word); Assembler;
asm
        mov    bx, hz
        mov    ax, $34DD
        mov    dx, $0012
        cmp    dx, bx
        jnb    @j1
        div    bx
        mov    bx, ax
        IN     al, $61
        test   al, $03
        jnz    @j2
        or     al, $03
        out    $61, al
        mov    al, $B6
        out    $43, al
@j2:
        mov    al, bl
        out    $42, al
        mov    al, bh
        out    $42, al
@j1:
end;

procedure nosound; Assembler;
asm
        in     al, $61
        and    al, $FC
        out    $61, al
end;

procedure Draw(var buf);assembler;
asm
        PUSH ES
        PUSH DS
        MOV  AX, $B800
        MOV  ES, AX
        LDS  SI, buf
        MOV  CX, 40*25
        MOV  AH, $0F
        XOR  DI, DI
        CLD
@cont:
        LODSB
        STOSW
        DEC  CX
        JNZ  @cont
        POP  DS
        POP  ES
end;

function Ticks:word;assembler;
asm
        push ds
        xor  ax, ax
        mov  ds, ax
        mov  ax, [$46C]
        pop  ds
end;

function TicksFrom(i : word):word;assembler;
asm
        push ds
        xor  ax, ax
        mov  ds, ax
        mov  ax, [$46C]
        pop  ds
        mov  bx, i
        cmp  ax, bx
        jge  @great
        neg  ax
        add  ax, bx
        jmp  @end
@great:
        sub ax, bx
@end:
end;

const
 figures : array[0..7] of string[12] = (
         '  *  ***    ',
         ' ***  *     ',
         '****        ',
         ' **   **    ',
         '**   **     ',
         '**  **      ',
         '    ***   * ',
         '  * ***     '
         );

CH_VL    = #$BA;
CH_HL    = #$C4;
CH_LC    = #$D3;
CH_RC    = #$BD;
CH_DOT   = '.';
CH_EMPTY = ' ';
CH_RB    = #$B2;
CH_GB    = #$B0;
CH_FULL  = #$B1;
var
        screen       : array [0..24, 0..39] of char;
        field        : array [0..19, 0..9] of char;
        figure_field : array[0..3, 0..3] of char;
        fig_i, fig_n : integer;
        fig_x, fig_y : integer;
        fig_a        : integer;
        fig_w, fig_h : integer;
        pause        : integer;
        lines        : integer;
        muted        : boolean;

function is_fig_line_empty(line : integer):boolean;
var x : integer;
begin
        for x := 0 to 3 do if figure_field[line, x] <> CH_EMPTY then begin is_fig_line_empty := false; exit; end;
        is_fig_line_empty := true;
end;

function is_fig_col_empty(col : integer):boolean;
var y : integer;
begin
        for y := 0 to 3 do if figure_field[y, col] <> CH_EMPTY then begin is_fig_col_empty := false; exit; end;
        is_fig_col_empty := true;
end;

procedure LoadFigure;
var figure : string[12];
    x, y   : integer;
begin
        fillchar(figure_field, 16, CH_EMPTY);
        figure := figures[fig_i];
        if fig_a = 0 then begin
                for y := 0 to 2 do for x := 0 to 3 do begin
                        if figure[1 + y * 4 + x] <> ' ' then figure_field[y, x] := CH_RB;
                end;
        end else if fig_a = 1 then begin
                for y := 0 to 2 do for x := 0 to 3 do begin
                        if figure[1 + y * 4 + x] <> ' ' then figure_field[3 - x, y] := CH_RB;
                end;
        end else if fig_a = 2 then begin
                for y := 0 to 2 do for x := 0 to 3 do begin
                        if figure[1 + y * 4 + x] <> ' ' then figure_field[3 - y, 3 - x] := CH_RB;
                end;
        end else if fig_a = 3 then begin
                for y := 0 to 2 do for x := 0 to 3 do begin
                        if figure[1 + y * 4 + x] <> ' ' then figure_field[x, 3 - y] := CH_RB;
                end;
        end;

        while is_fig_line_empty(0) do begin
                for y := 1 to 3 do move(figure_field[y, 0], figure_field[y - 1, 0], 4);
                fillchar(figure_field[3, 0], 4, CH_EMPTY);
        end;
        while is_fig_col_empty(0) do begin
                for y := 0 to 3 do move(figure_field[y, 1], figure_field[y, 0], 4);
                for y := 0 to 3 do figure_field[y, 3] := CH_EMPTY;
        end;
        fig_w := 4;
        while (fig_w > 0) and (is_fig_col_empty(fig_w - 1)) do fig_w := fig_w - 1;
        fig_h := 4;
        while (fig_h > 0) and (is_fig_line_empty(fig_h - 1)) do fig_h := fig_h - 1;
        if fig_w + fig_x > 10 then fig_x := 10 - fig_w;
end;

procedure ReDraw;
var figure : string[12];
    x, y   : integer;
    c      : char;
begin
        fillchar(screen, 25 * 40, CH_EMPTY);
        for y := 1 to 21 do begin
                screen[y, 15] := CH_VL;
                screen[y, 26] := CH_VL;
        end;
        fillchar(screen[21, 15], 12, CH_HL);
        screen[21, 15] := CH_LC;
        screen[21, 26] := CH_RC;
        for y := 0 to 19 do begin
                fillchar(screen[y + 1, 16], 10, CH_DOT);
                for x := 0 to 9 do begin
                        c := field[y, x];
                        if c <> CH_EMPTY then screen[y + 1, x + 16] := c;
                end;
        end;
        for y := 0 to 3 do
                for x := 0 to 3 do begin
                        c := figure_field[y, x];
                        if c <> CH_EMPTY then screen[1 + fig_y + y, 16 + fig_x + x] := c;
                end;
        figure := figures[fig_n];
        for y := 0 to 2 do
                for x := 0 to 3 do
                        if figure[y * 4 + x + 1] <> ' ' then screen[y + 1, x + 29] := CH_GB;
        Draw(screen);
end;

function Can_move_left : boolean;
var x, y : integer;
begin
        if fig_x = 0 then begin Can_move_left := false; exit; end;
        for y := 0 to 3 do
                for x := 0 to 3 do
                        if (figure_field[y, x] <> CH_EMPTY)
                                and (field[fig_y + y, fig_x + x - 1] <> CH_EMPTY) then begin
                                Can_move_left := false;
                                exit;
                        end;
        Can_move_left := true;
end;

function Can_move_right : boolean;
var x, y : integer;
begin
        if fig_x + fig_w >= 10 then begin Can_move_right := false; exit; end;
        for y := 0 to 3 do
                for x := 0 to 3 do
                        if (figure_field[y, x] <> CH_EMPTY)
                                and (field[fig_y + y, fig_x + x + 1] <> CH_EMPTY) then begin
                                Can_move_right := false;
                                exit;
                        end;
        Can_move_right := true;
end;

function Can_do_step_down : boolean;
var x, y : integer;
begin
        for y := 0 to 3 do
                for x := 0 to 3 do
                        if (figure_field[y, x] <> CH_EMPTY)
                                and (field[fig_y + y + 1, fig_x + x] <> CH_EMPTY) then begin
                                Can_do_step_down := false;
                                exit;
                        end;
        Can_do_step_down := true;
end;

procedure Figure_Merge;
var x, y : integer;
begin
        for y := 0 to 3 do
                for x := 0 to 3 do if figure_field[y, x] <> CH_EMPTY then field[fig_y + y, fig_x + x] := CH_GB;
end;

procedure Remove_Rows;
var x, y   : integer;
    candel : boolean;
    time   : integer;
begin
        y := 19;
        while y > 0 do begin
                candel := true;
                for x := 0 to 9 do if field[y, x] = CH_EMPTY then candel := false;
                if candel then begin
                        Fillchar(field[y, 0], 10, CH_FULL);
                        ReDraw;
                        if not muted then sound(100);
                        time := Ticks;
                        while TicksFrom(time) < 4 do ;
                        move(field, field[1, 0], (y) * 10);
                        fillchar(field, 10, CH_EMPTY);
                        lines := lines + 1;
                        if (lines mod 20) = 19 then pause := pause - 1;
                        if not muted then nosound;
                end else y := y - 1;
        end;
end;

procedure Next_Figure;
var time : integer;
begin
        if not muted then sound(60);
        time := Ticks;
        fig_a := 0;
        fig_x := 4;
        fig_y := 0;
        fig_i := fig_n;
        fig_n := random(8);
        while TicksFrom(time) < 1 do ;
        LoadFigure;
        if not muted then nosound;
end;

function Figure_is_down:boolean;
begin
        Figure_is_down := (fig_y + fig_h - 1) = 19;
end;

procedure Game;
var key         : integer;
    key_scan    : integer;
    need_redraw : boolean;
    time        : integer;
    steps       : integer;
    fall        : boolean;
begin
        fillchar(field, 20 * 10, CH_EMPTY);
        muted := false;
        pause := 7;
        lines := 0;
        fig_n := random(8);
        Next_Figure;
        need_redraw := true;
        time := Ticks;
        steps := 0;
        fall := false;
        while true do begin
                if need_redraw then begin
                        ReDraw;
                        need_redraw := false;
                end;
                if HasKey then begin
                        key := GetKey;
                        key_scan := hi(key);
                        if key_scan = 1 then exit
                        else if (key_scan = $4b) and Can_move_left then begin
                                fig_x := fig_x - 1;
                                need_redraw := true;
                        end else if (key_scan = $4d) and Can_move_right then begin
                                fig_x := fig_x + 1;
                                need_redraw := true;
                        end else if key_scan = $48 then begin
                                fig_a := (fig_a + 1) and 3;
                                LoadFigure;
                                need_redraw := true;
                        end else if key_scan = $50 then begin
                                fig_a := (fig_a - 1) and 3;
                                LoadFigure;
                                need_redraw := true;
                        end else if key_scan = $19 then begin
                                key := GetKey;
                        end else if key_scan = $39 then begin
                                fall := true;
                        end else if key_scan = $32 then begin
                                muted := not muted;
                        end;
                end else if (not Can_do_step_down)
                        or Figure_is_down then begin
                        if steps = 0 then exit;
                        Figure_Merge;
                        Next_Figure;
                        Remove_Rows;
                        steps := 0;
                        fall := false;
                        need_redraw := true;
                end else if fall then begin
                        if not muted then sound(80);
                        fig_y := fig_y + 1;
                        need_redraw := true;
                        time := Ticks;
                        steps := steps + 1;
                        if not muted then Nosound;
                end else if TicksFrom(time) > pause then begin
                        if not muted then sound(80);
                        fig_y := fig_y + 1;
                        need_redraw := true;
                        time := Ticks;
                        steps := steps + 1;
                        if not muted then Nosound;
                end;
        end;
end;

procedure WaitKey;
var key : integer;
begin
        while HasKey do key := GetKey;
        key := GetKey;
end;

begin
        Randomize;
        Text40x25Mode;
        Locate(100, 100);
        Game;
        WaitKey;
        TextMode;
end.
