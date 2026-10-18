import Foundation

extension String {
    /// Minúsculas e sem acentos, para pesquisa insensível a maiúsculas/acentuação.
    var searchNormalized: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

struct CatalogItem: Identifiable, Hashable {
    let id   = UUID()
    let name: String
    let category: ItemCategory
}

enum CatalogData {
    static let all: [CatalogItem] = carnePeixe + vegetaisFruta + laticinios
                                  + padaria + conservasSecos + limpeza
                                  + higiene + bebidas + snacks + congelados
                                  + bebeCrianca + animais + casa + outros

    // MARK: Carne & Peixe
    static let carnePeixe: [CatalogItem] = items(.carnePeixe,
        "Frango inteiro", "Peito de frango", "Coxas de frango", "Asas de frango",
        "Carne picada de vaca", "Carne picada de porco", "Bife de vaca",
        "Entrecosto de porco", "Lombo de porco", "Costelas de porco",
        "Salpicão", "Chouriço", "Linguiça", "Morcela", "Alheira",
        "Fiambre", "Presunto", "Bacon", "Salsicha de porco",
        "Salmão", "Pescada", "Filetes de pescada", "Bacalhau",
        "Sardinha fresca", "Camarão", "Polvo", "Lulas", "Amêijoas",
        "Atum fresco", "Dourada", "Robalo", "Perca",
        "Peru fatiado", "Peito de peru", "Coelho", "Costeletas de porco",
        "Rojões", "Farinheira", "Paio", "Mortadela", "Fiambre de peru",
        "Chocos", "Mexilhão", "Berbigão", "Percebes", "Carapau",
        "Cavala fresca", "Solha", "Tamboril", "Enguias", "Pratos prontos de peixe",
        "Vitela", "Bife do lombo", "Bife da vazia", "Novilho", "Naco de vaca",
        "Hambúrguer de vaca", "Almôndegas", "Frango desfiado", "Peito de frango fatiado",
        "Perna de frango", "Fígado de frango", "Frango temperado", "Kebab de frango",
        "Presunto ibérico", "Chourição", "Toucinho", "Entremeada", "Carne de porco preto",
        "Costela de vaca", "Picanha", "Pargo", "Peixe-espada", "Faneca",
        "Truta", "Linguado", "Caranguejo", "Sapateira", "Lagosta congelada"
    )

    // MARK: Vegetais & Fruta
    static let vegetaisFruta: [CatalogItem] = items(.vegetaisFruta,
        "Tomate", "Tomate cherry", "Alface", "Rúcula", "Espinafres",
        "Cebola", "Cebola roxa", "Alho", "Cenoura", "Batata",
        "Batata-doce", "Courgette", "Pepino", "Pimento vermelho",
        "Pimento verde", "Pimento amarelo", "Brócolos", "Couve-flor",
        "Couve portuguesa", "Alho francês", "Cogumelos", "Beringela",
        "Abóbora", "Ervilhas", "Feijão verde", "Grelos", "Nabo",
        "Beterraba", "Aipo", "Maçã", "Pera", "Banana", "Laranja",
        "Limão", "Uvas", "Morango", "Kiwi", "Abacate", "Melão",
        "Manga", "Abacaxi", "Pêssego", "Nectarina", "Ameixa",
        "Framboesa", "Mirtilo", "Melancia", "Figo", "Tangerina",
        "Repolho", "Rabanete", "Espargos", "Alcachofra", "Chuchu",
        "Milho fresco", "Coco", "Romã", "Cereja", "Damasco",
        "Salsa", "Coentros", "Hortelã", "Manjericão", "Cebolinho",
        "Gengibre fresco", "Malagueta", "Alho-porro",
        "Alperce", "Groselha", "Physalis", "Papaia", "Maracujá",
        "Grapefruit", "Lima", "Endívias", "Escarola",
        "Agrião", "Funcho", "Aboborinha", "Batata nova", "Cebola francesa",
        "Alho novo", "Ervas provençais frescas", "Salsa fresca embalada",
        "Salada mista embalada", "Salada de rúcula e espinafres embalada",
        "Cenoura ralada embalada", "Legumes para sopa embalados"
    )

    // MARK: Laticínios
    static let laticinios: [CatalogItem] = items(.laticinios,
        "Leite meio-gordo", "Leite magro", "Leite gordo",
        "Iogurte natural", "Iogurte grego", "Iogurte de fruta",
        "Queijo flamengo", "Queijo fresco", "Requeijão",
        "Mozarela", "Queijo da Serra", "Queijo ralado",
        "Queijo parmesão", "Manteiga", "Natas", "Natas de cozinha",
        "Ovos M", "Ovos L", "Kefir", "Bebida de aveia",
        "Leite sem lactose", "Iogurte líquido natural", "Iogurte skyr",
        "Queijo cottage", "Queijo brie", "Queijo cabra",
        "Queijo em fatias", "Nata para bater", "Margarina",
        "Leite condensado", "Leite em pó", "Sobremesa de ovos",
        "Leite sem lactose meio-gordo", "Iogurte proteico", "Iogurte de soja",
        "Queijo edam", "Queijo emmental", "Queijo gouda", "Queijo azul",
        "Queijo philadelphia", "Queijo em barra ralável", "Manteiga sem sal",
        "Natas vegetais", "Pudim", "Mousse de chocolate", "Arroz doce embalado",
        "Leite fermentado", "Ovos XL", "Ovos biológicos", "Manteiga com sal",
        "Chantilly", "Ovos de codorniz"
    )

    // MARK: Padaria
    static let padaria: [CatalogItem] = items(.padaria,
        "Pão de forma branco", "Pão de forma integral",
        "Baguete", "Pão de mistura", "Pão integral",
        "Pão de centeio", "Broa de milho", "Pão ralado",
        "Croissant", "Tostas", "Bolacha Maria",
        "Bolacha de água e sal", "Bolacha de aveia",
        "Bolachas de chocolate", "Bolo de iogurte",
        "Tarte de nata", "Pão de leite",
        "Pão de hambúrguer", "Pão de cachorro", "Pão sem glúten",
        "Wrap", "Pão pita", "Muffin inglês", "Papo-seco",
        "Bolo rei", "Bolo de chocolate", "Pastel de nata",
        "Pão saloio", "Pão alentejano", "Regueifa", "Bolinhos de bacalhau de padaria",
        "Folhado de salsicha", "Bola de Berlim", "Palmier", "Bolachas de manteiga",
        "Bolachas digestivas", "Panetone", "Bolo de aniversário", "Massa folhada",
        "Massa quebrada", "Pão de forma sem gluten", "Broa de avintes"
    )

    // MARK: Conservas & Secos
    static let conservasSecos: [CatalogItem] = items(.conservasSecos,
        "Arroz agulha", "Arroz carolino", "Arroz integral",
        "Massa esparguete", "Massa penne", "Massa fusilli",
        "Massa lasanha", "Massa tagliatelle", "Macarrão",
        "Feijão cozido", "Feijão encarnado", "Grão de bico",
        "Lentilhas", "Ervilhas em lata", "Milho em lata",
        "Atum em lata", "Sardinha em lata", "Cavala em lata",
        "Tomate pelado", "Polpa de tomate", "Concentrado de tomate",
        "Azeitonas", "Cogumelos em lata", "Ananás em lata",
        "Azeite", "Óleo alimentar", "Vinagre", "Vinagre balsâmico",
        "Sal fino", "Sal grosso", "Açúcar branco", "Açúcar amarelo",
        "Farinha de trigo", "Farinha de milho", "Fermento",
        "Bicarbonato de sódio", "Amido de milho",
        "Cacau em pó", "Chocolate para culinária",
        "Mel", "Doce de morango", "Doce de laranja",
        "Manteiga de amendoim", "Tahini",
        "Caldo de galinha", "Caldo de legumes",
        "Molho de tomate", "Ketchup", "Mostarda",
        "Maionese", "Molho de soja", "Molho inglês",
        "Orégãos", "Louro", "Pimentão doce", "Cominhos",
        "Canela", "Noz-moscada", "Açafrão das Índias",
        "Massa esparguete integral", "Cuscuz", "Quinoa", "Aveia em flocos",
        "Puré de batata instantâneo", "Sopa instantânea", "Noodles instantâneos",
        "Leite de coco", "Vinho do Porto para cozinhar", "Piri-piri",
        "Pimenta preta", "Pimenta branca", "Alho em pó", "Cebola em pó",
        "Adoçante", "Vanilha", "Fermento em pó", "Coco ralado",
        "Chocolate em pó", "Compota de framboesa",
        "Arroz basmati", "Arroz vaporizado", "Massa integral penne",
        "Massa para lasanha fresca", "Ravioli seco", "Farinha sem glúten",
        "Farinha integral", "Fermento de padeiro", "Levedura",
        "Feijão manteiga", "Feijão branco", "Grão de bico cozido lata",
        "Milho doce lata", "Espargos em lata", "Palmito em lata",
        "Pickles", "Cebolinhas em vinagre", "Cogumelos secos",
        "Tomate seco", "Chocolate culinário negro", "Cobertura de chocolate",
        "Pastilhas de caldo Knorr", "Molho barbecue", "Molho piri-piri",
        "Molho tártaro", "Vinagrete", "Azeite virgem extra",
        "Óleo de girassol", "Óleo de coco", "Água-pé", "Sidra para cozinhar",
        "Especiarias mistas para churrasco", "Alecrim seco", "Tomilho seco"
    )

    // MARK: Limpeza
    static let limpeza: [CatalogItem] = items(.limpeza,
        "Detergente loiça", "Detergente máquina loiça",
        "Cápsulas máquina loiça", "Sal máquina loiça",
        "Detergente máquina roupa", "Cápsulas máquina roupa",
        "Suavizante", "Lixívia", "Água oxigenada",
        "Limpador multiusos", "Limpador casa de banho",
        "Produto WC", "Desengordurante",
        "Limpador vidros", "Limpa-metais",
        "Esponjas de cozinha", "Esfregão",
        "Luvas de borracha", "Pano de microfibra",
        "Sacos de lixo grandes", "Sacos de lixo pequenos",
        "Rolo de papel de cozinha", "Papel higiénico",
        "Guardanapos de papel", "Toalhetes húmidos",
        "Inseticida", "Ambientador",
        "Detergente para tapetes", "Tira-nódoas", "Amaciador de roupa concentrado",
        "Pastilhas WC", "Vassoura", "Apanhador de lixo", "Rodo",
        "Balde", "Panos de limpeza", "Esfregona", "Sacos aspirador",
        "Detergente para chão de madeira",
        "Removedor de manchas", "Pastilhas para lava-loiça",
        "Abrilhantador máquina loiça", "Anti-calcário", "Desentupidor de canos",
        "Spray anti-mofo", "Espanador", "Rolo tira-pó", "Panos de chão",
        "Recarga difusor elétrico",
        "Refil ambientador", "Bloco sanitário WC", "Escova sanitária",
        "Toalhitas para pó", "Papel de cozinha reciclado",
        "Sacos para caixote reciclagem", "Filtro exaustor", "Saco aspirador robô"
    )

    // MARK: Higiene
    static let higiene: [CatalogItem] = items(.higiene,
        "Champô", "Champô anticaspa", "Condicionador",
        "Máscara de cabelo", "Gel de banho", "Sabonete",
        "Gel de limpeza facial", "Creme hidratante rosto",
        "Leite corporal", "Creme de mãos",
        "Pasta de dentes", "Escova de dentes",
        "Elixir bocal", "Fio dentário",
        "Desodorizante spray", "Desodorizante stick",
        "Protetor solar", "After-sun",
        "Espuma de barbear", "Gel de barbear",
        "Máquinas de barbear", "Lâminas de barbear",
        "Pensos higiénicos", "Tampões", "Pensos diários",
        "Cotonetes", "Algodão", "Banda-d'adesivo",
        "Gel desinfetante", "Toalhetes desmaquilhantes",
        "Perfume", "Verniz de unhas", "Removedor de verniz",
        "Aparelho de barbear descartável", "Pente", "Escova de cabelo",
        "Fixador de cabelo", "Laca", "Preservativos", "Teste de gravidez",
        "Óleo corporal", "Creme anti-idade", "Sérum facial", "Água micelar",
        "Tónico facial", "Máscara facial", "Esfoliante corporal",
        "Sabonete líquido", "Sabonete de mãos", "Talco", "Cotonetes de bebé",
        "Aparelho de depilar", "Cera depilatória", "Creme depilatório",
        "Escova interdentária", "Pasta de dentes branqueadora",
        "Colutório", "Palhinhas dentárias", "Compressas", "Adesivo cirúrgico",
        "Máscaras descartáveis", "Termómetro", "Álcool desinfetante",
        "Analgésico", "Antitérmico", "Vitamina C", "Multivitamínico"
    )

    // MARK: Bebidas
    static let bebidas: [CatalogItem] = items(.bebidas,
        "Água sem gás", "Água com gás",
        "Sumo de laranja", "Sumo de maçã", "Sumo de uva",
        "Sumo de pêssego", "Sumo de tomate",
        "Limonada", "Ice tea", "Refrigerante cola",
        "Refrigerante laranja", "Tónica",
        "Cerveja", "Cerveja sem álcool",
        "Vinho tinto", "Vinho branco", "Vinho rosé",
        "Espumante", "Sangria",
        "Café grão", "Café moído", "Cápsulas de café",
        "Descafeinado", "Chá verde", "Chá preto",
        "Chá de camomila", "Chá de hortelã",
        "Leite vegetal de aveia", "Leite vegetal de amêndoa",
        "Kombucha", "Bebida energética",
        "Água tónica", "Leite achocolatado", "Iced coffee",
        "Vinho verde", "Whisky", "Vodka", "Gin", "Rum",
        "Licor", "Bebida isotónica", "Chá gelado de limão",
        "Água das pedras", "Água mineral 1,5L", "Água mineral 5L",
        "Sumo de manga", "Sumo de ananás", "Néctar de pera",
        "Refrigerante de laranja sem açúcar", "Refrigerante lima-limão",
        "Sumo detox", "Água aromatizada", "Bebida de soja",
        "Bebida de arroz", "Leite meio-gordo sem lactose UHT",
        "Café solúvel", "Chá de gengibre", "Chá de frutos vermelhos",
        "Bagaço", "Aguardente", "Absinto", "Tequila", "Conhaque",
        "Vermute", "Cerveja artesanal", "Cerveja preta", "Sidra"
    )

    // MARK: Snacks
    static let snacks: [CatalogItem] = items(.snacks,
        "Batatas fritas", "Chips de milho",
        "Pipocas", "Amendoins", "Cajus",
        "Amêndoas", "Nozes", "Passas",
        "Mix de frutos secos", "Tâmaras",
        "Barra de cereais", "Barra de proteína",
        "Granola", "Muesli",
        "Chocolate de leite", "Chocolate negro",
        "Chocolate branco", "Gomas", "Rebuçados",
        "Bolachas de arroz", "Crackers",
        "Palitos de queijo", "Nachos",
        "Iogurte líquido",
        "Batatas fritas onduladas", "Pipocas de micro-ondas", "Azeitonas recheadas",
        "Pastéis de bacalhau", "Rissóis", "Croquetes", "Empadas",
        "Waffles", "Panquecas", "Barritas de cereais infantis",
        "Bolachas recheadas", "Bolachas de chocolate com côco", "Wafers",
        "Doritos", "Pringles", "Torresmos", "Frutas cristalizadas",
        "Barras de fruta", "Chocolate com avelãs", "Marshmallows",
        "Alcaçuz", "Amendoim garapiñado", "Batata palha", "Pastilha elástica",
        "Rebuçados de mentol"
    )

    // MARK: Congelados
    static let congelados: [CatalogItem] = items(.congelados,
        "Gelado", "Gelado de pauzinho", "Piza congelada", "Batatas fritas congeladas",
        "Legumes ultracongelados", "Ervilhas congeladas", "Espinafres congelados",
        "Brócolos congelados", "Massa folhada congelada", "Croquetes congelados",
        "Rissóis congelados", "Pastéis de bacalhau congelados", "Nuggets de frango",
        "Douradinhos", "Filetes de peixe congelados", "Camarão congelado",
        "Lulas congeladas", "Salmão congelado", "Bacalhau congelado",
        "Frutos vermelhos congelados", "Gelo em cubos", "Lasanha congelada pronta",
        "Empadão de carne congelado", "Sopa congelada", "Baguete para assar",
        "Croissant congelado para assar", "Hambúrguer vegetariano congelado",
        "Frango inteiro congelado", "Massa fresca congelada", "Alheira congelada",
        "Pão de forma congelado"
    )

    // MARK: Bebé & Criança
    static let bebeCrianca: [CatalogItem] = items(.bebeCrianca,
        "Fraldas bebé", "Toalhitas bebé", "Leite corporal bebé",
        "Champô bebé", "Leite em pó para bebé", "Boião de papa",
        "Boião de fruta bebé", "Água para biberão", "Chupeta",
        "Biberão", "Fraldas de banho", "Creme para assaduras",
        "Sabonete de bebé", "Óleo de bebé", "Toalhitas de mão bebé",
        "Fraldas nadador", "Leite de transição", "Cereais para bebé",
        "Boião de legumes bebé", "Compota infantil sem açúcar"
    )

    // MARK: Animais
    static let animais: [CatalogItem] = items(.animais,
        "Comida para cão", "Comida para gato", "Ração seca para cão",
        "Ração seca para gato", "Ração húmida para gato", "Ração húmida para cão",
        "Areia para gato", "Ração para pássaros", "Petiscos para cão",
        "Petiscos para gato", "Sacos para dejetos", "Brinquedo para gato",
        "Brinquedo para cão", "Champô para animais", "Antipulgas",
        "Comida para peixes", "Alpiste"
    )

    // MARK: Casa
    static let casa: [CatalogItem] = items(.casa,
        "Lâmpada LED", "Pilhas AA", "Pilhas AAA", "Pilhas botão",
        "Pilhas D", "Pilhas C", "Pilhas recarregáveis",
        "Fita adesiva", "Extensão elétrica", "Ficha tripla",
        "Isqueiro", "Fósforos", "Velas"
    )

    // MARK: Outros
    static let outros: [CatalogItem] = items(.outros,
        "Papel de alumínio", "Película aderente",
        "Papel vegetal", "Sacos de congelação",
        "Sacos de fecho zip", "Palitos",
        "Filtros de café", "Cápsulas Nespresso",
        "Palhinhas", "Papel de embrulho",
        "Detergente louça à mão", "Postal", "Saco de compras reutilizável",
        "Rede para fruta", "Etiqueta para malas", "Vela de aniversário"
    )

    // MARK: Helper
    private static func items(_ category: ItemCategory, _ names: String...) -> [CatalogItem] {
        names.map { CatalogItem(name: $0, category: category) }
    }
}
