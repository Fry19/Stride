import Foundation

public struct Coordinate: Codable, Hashable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Distance to `other` in kilometers, along the Earth's surface.
    public func km(to other: Coordinate) -> Double {
        let radians = Double.pi / 180
        let dLat = (other.latitude - latitude) * radians
        let dLon = (other.longitude - longitude) * radians
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(latitude * radians) * cos(other.latitude * radians) * sin(dLon / 2) * sin(dLon / 2)
        return 6_371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// A place on a route, `km` from the route's start. For the famous trails, distances and
/// positions are approximate.
public struct Stop: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let km: Double
    public let fact: String
    public let latitude: Double
    public let longitude: Double

    public init(id: String, name: String, km: Double, fact: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.km = km
        self.fact = fact
        self.latitude = latitude
        self.longitude = longitude
    }

    public var coordinate: Coordinate { Coordinate(latitude: latitude, longitude: longitude) }
}

public struct Route: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let region: String
    public let stops: [Stop]
    /// The line drawn on the map: a real walking route for nearby journeys, or straight lines between stops.
    public let path: [Coordinate]

    public init(id: String, name: String, region: String, stops: [Stop], path: [Coordinate]? = nil) {
        self.id = id
        self.name = name
        self.region = region
        self.stops = stops
        self.path = path ?? stops.map(\.coordinate)
    }

    public var lengthKm: Double { stops.last?.km ?? 0 }
}

/// A journey the user chose, walked from `startDay` until it's finished or they switch.
public struct JourneyPlan: Codable, Hashable {
    public var route: Route
    public var startDay: Day
    /// The last day counted, set when the user switches to another journey.
    public var endDay: Day?

    public init(route: Route, startDay: Day, endDay: Day? = nil) {
        self.route = route
        self.startDay = startDay
        self.endDay = endDay
    }
}

public enum Journeys {
    /// Famous long-distance walks to choose from.
    public static let epic: [Route] = [incaTrail, hadriansWall, caminoFrances, appalachianTrail, route66]

    /// XP for finishing a journey: 100 per kilometer, at least 500.
    public static func xp(for route: Route) -> Int {
        max(500, Int(route.lengthKm * 100))
    }

    static let incaTrail = Route(id: "inca", name: "Inca Trail", region: "Peru", stops: [
        Stop(id: "inca.km82", name: "Km 82", km: 0,
             fact: "The classic trail starts at a checkpoint beside kilometre 82 of the Cusco–Machu Picchu railway.",
             latitude: -13.2367, longitude: -72.3926),
        Stop(id: "inca.wayllabamba", name: "Wayllabamba", km: 12,
             fact: "The last village on the trail and a common first-night camp.",
             latitude: -13.26, longitude: -72.429),
        Stop(id: "inca.pass", name: "Dead Woman's Pass", km: 21,
             fact: "Warmiwañusca, the trail's highest point at about 4,215 m (13,828 ft).",
             latitude: -13.2428, longitude: -72.4842),
        Stop(id: "inca.runkurakay", name: "Runkurakay", km: 26,
             fact: "A small, round Inca ruin on the climb to the second pass.",
             latitude: -13.2283, longitude: -72.502),
        Stop(id: "inca.sayacmarca", name: "Sayacmarca", km: 29,
             fact: "Usually translated as \"inaccessible town\". It sits on a steep rocky spur.",
             latitude: -13.2281, longitude: -72.5158),
        Stop(id: "inca.phuyupatamarca", name: "Phuyupatamarca", km: 33,
             fact: "\"Town above the clouds\", with a chain of stone ritual baths.",
             latitude: -13.2066, longitude: -72.5325),
        Stop(id: "inca.winaywayna", name: "Wiñay Wayna", km: 38,
             fact: "\"Forever young\": stone terraces that fall away toward the Urubamba River.",
             latitude: -13.1919, longitude: -72.5364),
        Stop(id: "inca.sungate", name: "Inti Punku", km: 41,
             fact: "The Sun Gate, where hikers get their first view of Machu Picchu.",
             latitude: -13.168, longitude: -72.539),
        Stop(id: "inca.machupicchu", name: "Machu Picchu", km: 43,
             fact: "The 15th-century Inca citadel at the end of the trail.",
             latitude: -13.1631, longitude: -72.545),
    ])

    static let hadriansWall = Route(id: "hadrian", name: "Hadrian's Wall Path", region: "England", stops: [
        Stop(id: "hadrian.wallsend", name: "Wallsend", km: 0,
             fact: "Segedunum fort marks the wall's eastern end on the River Tyne.",
             latitude: 54.9881, longitude: -1.5323),
        Stop(id: "hadrian.newcastle", name: "Newcastle upon Tyne", km: 7,
             fact: "Pons Aelius, a Roman fort and bridge, stood where the city's castle keep is now.",
             latitude: 54.9686, longitude: -1.6107),
        Stop(id: "hadrian.heddon", name: "Heddon-on-the-Wall", km: 24,
             fact: "The first stretch of standing wall on the walk west.",
             latitude: 54.9978, longitude: -1.7926),
        Stop(id: "hadrian.chesters", name: "Chesters", km: 48,
             fact: "A Roman cavalry fort with a well-preserved bathhouse beside the North Tyne.",
             latitude: 55.0255, longitude: -2.1397),
        Stop(id: "hadrian.housesteads", name: "Housesteads", km: 63,
             fact: "Vercovicium, often called the most complete Roman fort in Britain.",
             latitude: 55.0133, longitude: -2.3306),
        Stop(id: "hadrian.sycamoregap", name: "Sycamore Gap", km: 65,
             fact: "Known for its lone sycamore tree, which was illegally felled in 2023.",
             latitude: 55.0039, longitude: -2.3711),
        Stop(id: "hadrian.birdoswald", name: "Birdoswald", km: 83,
             fact: "Banna, a Roman fort on a bluff above the River Irthing.",
             latitude: 54.9894, longitude: -2.6025),
        Stop(id: "hadrian.carlisle", name: "Carlisle", km: 113,
             fact: "Roman Luguvalium. Tullie House museum displays finds from the wall.",
             latitude: 54.8925, longitude: -2.9329),
        Stop(id: "hadrian.bowness", name: "Bowness-on-Solway", km: 135,
             fact: "Maia fort, the wall's western end on the Solway Firth.",
             latitude: 54.9531, longitude: -3.2131),
    ])

    static let caminoFrances = Route(id: "camino", name: "Camino de Santiago", region: "France & Spain", stops: [
        Stop(id: "camino.sjpp", name: "Saint-Jean-Pied-de-Port", km: 0,
             fact: "The town at the foot of the Pyrenees where most pilgrims on the Camino Francés start.",
             latitude: 43.1636, longitude: -1.2366),
        Stop(id: "camino.roncesvalles", name: "Roncesvalles", km: 25,
             fact: "The first stop in Spain after the climb over the Pyrenees.",
             latitude: 43.0092, longitude: -1.3194),
        Stop(id: "camino.pamplona", name: "Pamplona", km: 68,
             fact: "Home of the San Fermín festival and its running of the bulls each July.",
             latitude: 42.8125, longitude: -1.6458),
        Stop(id: "camino.puentelareina", name: "Puente la Reina", km: 92,
             fact: "Named for its Romanesque pilgrims' bridge over the River Arga.",
             latitude: 42.672, longitude: -1.8146),
        Stop(id: "camino.logrono", name: "Logroño", km: 162,
             fact: "Capital of the La Rioja wine region.",
             latitude: 42.4627, longitude: -2.445),
        Stop(id: "camino.burgos", name: "Burgos", km: 282,
             fact: "Its Gothic cathedral is a UNESCO World Heritage Site.",
             latitude: 42.3439, longitude: -3.6969),
        Stop(id: "camino.leon", name: "León", km: 465,
             fact: "Its cathedral is known for its vast expanse of medieval stained glass.",
             latitude: 42.5987, longitude: -5.5671),
        Stop(id: "camino.astorga", name: "Astorga", km: 512,
             fact: "Home to an Episcopal Palace designed by Antoni Gaudí.",
             latitude: 42.4589, longitude: -6.0563),
        Stop(id: "camino.cruzdeferro", name: "Cruz de Ferro", km: 538,
             fact: "An iron cross where pilgrims leave a stone carried from home.",
             latitude: 42.4886, longitude: -6.3614),
        Stop(id: "camino.ocebreiro", name: "O Cebreiro", km: 618,
             fact: "A mountain village at the entrance to Galicia, known for its round stone pallozas.",
             latitude: 42.7078, longitude: -7.0429),
        Stop(id: "camino.sarria", name: "Sarria", km: 665,
             fact: "The most popular start for walkers covering the final 100 km needed for a Compostela certificate.",
             latitude: 42.7811, longitude: -7.4142),
        Stop(id: "camino.santiago", name: "Santiago de Compostela", km: 780,
             fact: "The cathedral city where, by tradition, the apostle St James is buried.",
             latitude: 42.8806, longitude: -8.5446),
    ])

    static let appalachianTrail = Route(id: "appalachian", name: "Appalachian Trail", region: "Eastern United States", stops: [
        Stop(id: "appalachian.springer", name: "Springer Mountain", km: 0,
             fact: "The trail's southern end, on a peak in north Georgia.",
             latitude: 34.6268, longitude: -84.1938),
        Stop(id: "appalachian.clingmans", name: "Clingmans Dome", km: 322,
             fact: "The highest point on the whole trail, at 6,643 ft (2,025 m), in the Great Smoky Mountains.",
             latitude: 35.5628, longitude: -83.4985),
        Stop(id: "appalachian.damascus", name: "Damascus", km: 756,
             fact: "A Virginia town nicknamed \"Trail Town USA\", home of the yearly Trail Days festival.",
             latitude: 36.6332, longitude: -81.7887),
        Stop(id: "appalachian.mcafee", name: "McAfee Knob", km: 1_150,
             fact: "A rock ledge over the valley, often called the most photographed spot on the trail.",
             latitude: 37.3925, longitude: -80.0363),
        Stop(id: "appalachian.harpersferry", name: "Harpers Ferry", km: 1_650,
             fact: "Home of the Appalachian Trail Conservancy, where the Shenandoah meets the Potomac.",
             latitude: 39.3254, longitude: -77.7389),
        Stop(id: "appalachian.delawaregap", name: "Delaware Water Gap", km: 2_084,
             fact: "Where the trail crosses the Delaware River from Pennsylvania into New Jersey.",
             latitude: 40.9693, longitude: -75.1424),
        Stop(id: "appalachian.greylock", name: "Mount Greylock", km: 2_559,
             fact: "The highest point in Massachusetts.",
             latitude: 42.6376, longitude: -73.1662),
        Stop(id: "appalachian.washington", name: "Mount Washington", km: 3_009,
             fact: "New Hampshire's highest peak, known for some of the worst weather on Earth.",
             latitude: 44.2706, longitude: -71.3033),
        Stop(id: "appalachian.katahdin", name: "Katahdin", km: 3_536,
             fact: "The northern end of the trail, on Maine's highest mountain.",
             latitude: 45.9044, longitude: -68.9213),
    ])

    static let route66 = Route(id: "route66", name: "Route 66", region: "Chicago to Santa Monica", stops: [
        Stop(id: "route66.chicago", name: "Chicago", km: 0,
             fact: "The route begins on Adams Street, near the Art Institute.",
             latitude: 41.8796, longitude: -87.6237),
        Stop(id: "route66.stlouis", name: "St. Louis", km: 543,
             fact: "The Gateway Arch marks the city's place as the gateway to the West.",
             latitude: 38.6247, longitude: -90.1848),
        Stop(id: "route66.tulsa", name: "Tulsa", km: 1_266,
             fact: "Home of Cyrus Avery, often called the father of Route 66.",
             latitude: 36.1540, longitude: -95.9928),
        Stop(id: "route66.amarillo", name: "Amarillo", km: 1_935,
             fact: "Just outside town is Cadillac Ranch: ten Cadillacs buried nose-first in a field.",
             latitude: 35.2220, longitude: -101.8313),
        Stop(id: "route66.albuquerque", name: "Albuquerque", km: 2_459,
             fact: "Route 66 runs through the city as Central Avenue.",
             latitude: 35.0844, longitude: -106.6504),
        Stop(id: "route66.flagstaff", name: "Flagstaff", km: 3_047,
             fact: "A mountain town at about 7,000 ft, not far from the Grand Canyon.",
             latitude: 35.1983, longitude: -111.6513),
        Stop(id: "route66.santamonica", name: "Santa Monica Pier", km: 3_940,
             fact: "An \"End of the Trail\" sign on the pier marks the finish.",
             latitude: 34.0094, longitude: -118.4973),
    ])
}
