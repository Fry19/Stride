import Foundation

/// A place on a route, `km` from the route's start. Distances are approximate.
public struct Stop: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let km: Double
    public let fact: String
}

public struct Route: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let region: String
    public let stops: [Stop]

    public var lengthKm: Double { stops.last?.km ?? 0 }
}

/// A stop on the virtual journey, placed by the total distance walked since starting Stride.
public struct Milestone: Hashable {
    public let route: Route
    public let stop: Stop
    public let totalKm: Double
}

/// Routes are walked one after another: finish one and the next begins.
public enum Journeys {
    public static let routes: [Route] = [incaTrail, hadriansWall, caminoFrances]

    public static let milestones: [Milestone] = {
        var offset = 0.0
        var result: [Milestone] = []
        for route in routes {
            for stop in route.stops {
                result.append(Milestone(route: route, stop: stop, totalKm: offset + stop.km))
            }
            offset += route.lengthKm
        }
        return result
    }()

    public static var totalKm: Double { routes.reduce(0) { $0 + $1.lengthKm } }

    /// Distance at which `route` begins.
    public static func startKm(of route: Route) -> Double {
        var offset = 0.0
        for candidate in routes {
            if candidate.id == route.id { return offset }
            offset += candidate.lengthKm
        }
        return offset
    }

    static let incaTrail = Route(id: "inca", name: "Inca Trail", region: "Peru", stops: [
        Stop(id: "inca.km82", name: "Km 82", km: 0,
             fact: "The classic trail starts at a checkpoint beside kilometre 82 of the Cusco–Machu Picchu railway."),
        Stop(id: "inca.wayllabamba", name: "Wayllabamba", km: 12,
             fact: "The last village on the trail and a common first-night camp."),
        Stop(id: "inca.pass", name: "Dead Woman's Pass", km: 21,
             fact: "Warmiwañusca, the trail's highest point at about 4,215 m (13,828 ft)."),
        Stop(id: "inca.runkurakay", name: "Runkurakay", km: 26,
             fact: "A small, round Inca ruin on the climb to the second pass."),
        Stop(id: "inca.sayacmarca", name: "Sayacmarca", km: 29,
             fact: "Usually translated as \"inaccessible town\". It sits on a steep rocky spur."),
        Stop(id: "inca.phuyupatamarca", name: "Phuyupatamarca", km: 33,
             fact: "\"Town above the clouds\", with a chain of stone ritual baths."),
        Stop(id: "inca.winaywayna", name: "Wiñay Wayna", km: 38,
             fact: "\"Forever young\": stone terraces that fall away toward the Urubamba River."),
        Stop(id: "inca.sungate", name: "Inti Punku", km: 41,
             fact: "The Sun Gate, where hikers get their first view of Machu Picchu."),
        Stop(id: "inca.machupicchu", name: "Machu Picchu", km: 43,
             fact: "The 15th-century Inca citadel at the end of the trail."),
    ])

    static let hadriansWall = Route(id: "hadrian", name: "Hadrian's Wall Path", region: "England", stops: [
        Stop(id: "hadrian.wallsend", name: "Wallsend", km: 0,
             fact: "Segedunum fort marks the wall's eastern end on the River Tyne."),
        Stop(id: "hadrian.newcastle", name: "Newcastle upon Tyne", km: 7,
             fact: "Pons Aelius, a Roman fort and bridge, stood where the city's castle keep is now."),
        Stop(id: "hadrian.heddon", name: "Heddon-on-the-Wall", km: 24,
             fact: "The first stretch of standing wall on the walk west."),
        Stop(id: "hadrian.chesters", name: "Chesters", km: 48,
             fact: "A Roman cavalry fort with a well-preserved bathhouse beside the North Tyne."),
        Stop(id: "hadrian.housesteads", name: "Housesteads", km: 63,
             fact: "Vercovicium, often called the most complete Roman fort in Britain."),
        Stop(id: "hadrian.sycamoregap", name: "Sycamore Gap", km: 65,
             fact: "Known for its lone sycamore tree, which was illegally felled in 2023."),
        Stop(id: "hadrian.birdoswald", name: "Birdoswald", km: 83,
             fact: "Banna, a Roman fort on a bluff above the River Irthing."),
        Stop(id: "hadrian.carlisle", name: "Carlisle", km: 113,
             fact: "Roman Luguvalium. Tullie House museum displays finds from the wall."),
        Stop(id: "hadrian.bowness", name: "Bowness-on-Solway", km: 135,
             fact: "Maia fort, the wall's western end on the Solway Firth."),
    ])

    static let caminoFrances = Route(id: "camino", name: "Camino de Santiago", region: "France & Spain", stops: [
        Stop(id: "camino.sjpp", name: "Saint-Jean-Pied-de-Port", km: 0,
             fact: "The town at the foot of the Pyrenees where most pilgrims on the Camino Francés start."),
        Stop(id: "camino.roncesvalles", name: "Roncesvalles", km: 25,
             fact: "The first stop in Spain after the climb over the Pyrenees."),
        Stop(id: "camino.pamplona", name: "Pamplona", km: 68,
             fact: "Home of the San Fermín festival and its running of the bulls each July."),
        Stop(id: "camino.puentelareina", name: "Puente la Reina", km: 92,
             fact: "Named for its Romanesque pilgrims' bridge over the River Arga."),
        Stop(id: "camino.logrono", name: "Logroño", km: 162,
             fact: "Capital of the La Rioja wine region."),
        Stop(id: "camino.burgos", name: "Burgos", km: 282,
             fact: "Its Gothic cathedral is a UNESCO World Heritage Site."),
        Stop(id: "camino.leon", name: "León", km: 465,
             fact: "Its cathedral is known for its vast expanse of medieval stained glass."),
        Stop(id: "camino.astorga", name: "Astorga", km: 512,
             fact: "Home to an Episcopal Palace designed by Antoni Gaudí."),
        Stop(id: "camino.cruzdeferro", name: "Cruz de Ferro", km: 538,
             fact: "An iron cross where pilgrims leave a stone carried from home."),
        Stop(id: "camino.ocebreiro", name: "O Cebreiro", km: 618,
             fact: "A mountain village at the entrance to Galicia, known for its round stone pallozas."),
        Stop(id: "camino.sarria", name: "Sarria", km: 665,
             fact: "The most popular start for walkers covering the final 100 km needed for a Compostela certificate."),
        Stop(id: "camino.santiago", name: "Santiago de Compostela", km: 780,
             fact: "The cathedral city where, by tradition, the apostle St James is buried."),
    ])
}
