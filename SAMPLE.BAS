' SAMPLE.BAS - a QBasic program to try the highlighter on
'$DYNAMIC
DECLARE SUB DrawBox (x%, y%, w%, h%)
DECLARE FUNCTION Total# (a#(), n%)

DEFINT A-Z
CONST MaxItems = 10
DIM SHARED names$(1 TO MaxItems)
DIM prices#(1 TO MaxItems)

CLS
COLOR 14, 1
PRINT "Shopping list"
FOR i = 1 TO MaxItems
    READ names$(i), prices#(i)
NEXT i

10 PRINT "Total: "; USING "####.##"; Total#(prices#(), MaxItems)
Again:
    k$ = INKEY$
    IF k$ = "" THEN GOTO Again
    IF UCASE$(k$) = "Q" THEN END
    REM other keys draw a box
    CALL DrawBox(10, 5, 20, 3)
    x& = &HFF + &O17 + 70000&
    y! = .5 * 1.5E+3
GOTO Again

DATA Apples, 1.25, Bread, 2.50, Cheese, 4.75, Milk, .99, Rice, 3.20
DATA Tea, 2.10, Eggs, 2.30, Butter, 1.95, Jam, 3.05, Honey, 4.40

SUB DrawBox (x%, y%, w%, h%)
    LOCATE y%, x%: PRINT CHR$(218); STRING$(w% - 2, 196); CHR$(191)
    FOR r% = 1 TO h% - 2
        LOCATE y% + r%, x%: PRINT CHR$(179); SPACE$(w% - 2); CHR$(179)
    NEXT r%
    LOCATE y% + h% - 1, x%: PRINT CHR$(192); STRING$(w% - 2, 196); CHR$(217)
END SUB

FUNCTION Total# (a#(), n%)
    t# = 0
    FOR i% = 1 TO n%: t# = t# + a#(i%): NEXT
    Total# = t#
END FUNCTION
