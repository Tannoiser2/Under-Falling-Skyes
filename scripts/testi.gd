## Testi lunghi dell'interfaccia (riassunto delle regole).
class_name Testi
extends RefCounted

const REGOLE := """[font_size=26][b]Obiettivo[/b][/font_size]
Porta il segnalino ricerca (verde) in cima al tracciato ricerca prima che gli alieni distruggano la città. Perdi se il segnalino danno raggiunge il teschio della base o se la nave madre scende sulla riga del teschio.

Ogni turno ha tre fasi.

[font_size=26][b]1. Fase dei Dadi[/b][/font_size]
Hai 5 dadi lavoratore: 3 grigi e 2 bianchi. Piazzali uno alla volta, ciascuno in una colonna diversa della base (clicca un dado nel vassoio, poi uno spazio evidenziato).
• Ogni volta che piazzi un dado, tutte le navi in quella colonna scendono di tanti spazi quanto il valore del dado.
• Su una stanza con [b]cannone antiaereo[/b] le navi scendono di 1 spazio in meno (con un 1 non scendono).
• Dopo un dado [b]bianco[/b] rilanci tutti i dadi non ancora piazzati.
• Le navi innescano l'effetto dello spazio dove si fermano: le [b]frecce[/b] le spostano di lato, il simbolo della [b]nave madre[/b] la fa scendere di una riga (le navi su quella riga tornano sulla nave madre), i [b]teletrasporti[/b] le portano sul gemello. Le [b]esplosioni[/b] sono i bersagli dei tuoi caccia.
• Una nave che esce dal fondo del cielo colpisce la città: 1 danno, poi torna sulla nave madre.
• Solo un dado per turno può stare su uno spazio non ancora scavato, davanti all'escavatore, a una distanza non superiore al suo valore: servirà a far avanzare l'escavatore.

[font_size=26][b]2. Fase delle Stanze[/b][/font_size]
Risolvi i dadi nell'ordine che preferisci (clicca un dado sulla base per vedere cosa puoi fare).
• [b]Valore della stanza[/b] = dadi presenti ± modificatore. Una stanza su più spazi funziona solo se tutti gli spazi hanno un dado.
• [b]Costo[/b]: i fulmini sotto la stanza sono l'energia da pagare.
• [b]Energetica[/b] (gialla): aggiunge il valore all'energia.
• [b]Caccia[/b] (arancione): abbatte tutte le navi su spazi esplosione con numero minore o uguale al valore. Le viola tornano sulla nave madre, le bianche nella riserva.
• [b]Ricerca[/b] (verde): avanza sul tracciato ricerca; la somma dei numeri degli spazi superati non deve superare il valore.
• [b]Robot[/b] (blu): assembla un dado robot del valore della stanza (massimo 6) su uno spazio vuoto e scavato. I robot restano sulla base e funzionano come dadi lavoratore nei turni seguenti; dopo l'uso perdono 1 punto. Al massimo 2 robot.
• [b]Comando[/b] (viola): distribuisce il valore fra gli altri dadi lavoratore.
• [b]Escavatore[/b]: un dado su uno spazio non scavato, pagando 1 energia, fa avanzare l'escavatore fino a quello spazio.
• Cannoni antiaerei e cunicoli non hanno effetti in questa fase.

[font_size=26][b]3. Fase della Nave Madre[/b][/font_size]
È automatica: la nave madre scende di una riga (le navi che si trovano su quella riga tornano su di essa), poi esegue l'azione indicata a destra della sua riga (navi bianche in arrivo, escavatore o ricerca che arretrano, danno, discesa di tutte le navi) e infine sgancia le navi in attesa sui punti di sgancio liberi.

[font_size=26][b]Città, scenari e personaggi[/b][/font_size]
Ogni città ha un'abilità e una propria base. Gli scenari cambiano le regole della battaglia. Ogni personaggio ha un'abilità utilizzabile una volta per partita (pulsante [b]Usa[/b]).

[font_size=26][b]Difficoltà[/b][/font_size]
Il livello di minaccia è il numero di tessere cielo girate sul lato più minaccioso. Nelle partite singole il livello di difficoltà somma le stelle nere (tessere cielo minacciose e scenario) e sottrae le stelle gialle (personaggi promossi 1, personaggi non promossi e città danneggiata ½).

[font_size=26][b]Campagna[/b][/font_size]
Quattro capitoli, di solito una decina di partite. In ogni battaglia scegli fra due pile casuali (città, scenario, personaggio). Se perdi la prima partita ne giochi una seconda sul lato danneggiato della città. I personaggi che combattono con te tornano promossi nei capitoli successivi. Il punteggio finale è la somma dei livelli di minaccia delle partite vinte, meno 1 per ogni sconfitta.

[font_size=26][b]Comandi[/b][/font_size]
A sinistra il cielo, a destra il laboratorio (la base). Rotella: zoom. Tasto destro trascinato: sposta la vista. Doppio clic: torna alla vista intera. [b]Annulla[/b] torna indietro all'ultima mossa, ma non dopo un lancio di dadi."""
