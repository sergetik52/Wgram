import Foundation

public final class WgramRegistrationDate {
    private static let milestones: [(userId: Int64, timestamp: Int64)] = [
        (0, 1376438400),
        (2768409, 1383264000),
        (7679610, 1388448000),
        (11538514, 1391212800),
        (15835244, 1392854400),
        (23646077, 1393372800),
        (38015510, 1393632000),
        (44634663, 1399334400),
        (46145305, 1400112000),
        (54845238, 1411171200),
        (63263518, 1414368000),
        (101260938, 1425600000),
        (101323197, 1426204800),
        (103151531, 1433289600),
        (109393468, 1438992000),
        (112594714, 1439596800),
        (124872445, 1439769600),
        (125828524, 1444003200),
        (133909606, 1444176000),
        (143445125, 1448928000),
        (148670295, 1452211200),
        (152079341, 1453420800),
        (171295414, 1457481600),
        (181783990, 1460246400),
        (222021233, 1465344000),
        (225034354, 1466208000),
        (278941742, 1473465600),
        (285253072, 1476748800),
        (294851037, 1479513600),
        (297621225, 1481846400),
        (328594461, 1485561600),
        (337808429, 1487635200),
        (341546272, 1487721600),
        (352940995, 1487894400),
        (369669043, 1490918400),
        (400169472, 1501459200),
        (500000000, 1512086400),
        (700000000, 1541030400),
        (805158066, 1563148800),
        (1100000000, 1585699200),
        (1400000000, 1601510400),
        (1700000000, 1614556800),
        (1974255900, 1633996800),
        (5022636255, 1639094400),
        (5045293264, 1642032000),
        (5047148663, 1649116800),
        (5144324763, 1649203200),
        (5159326926, 1655337600),
        (5340744210, 1666742400),
        (5472518401, 1667347200),
        (5559594088, 1668038400),
        (5567880858, 1674604800),
        (5738347976, 1682380800),
        (5854845236, 1682553600),
        (5891297818, 1683158400),
        (5904140174, 1684540800),
        (6000582627, 1685404800),
        (6188508923, 1687392000),
        (6326011828, 1688688000),
        (6401027363, 1700870400),
        (6451891234, 1701475200),
        (6513268158, 1701475200),
        (6536173556, 1704931200),
        (6559717847, 1708819200),
        (6606876583, 1710633600),
        (6651640269, 1715990400),
        (6872061796, 1716595200),
        (7078066115, 1725753600),
        (7273085448, 1732147200),
        (7342300216, 1736985600),
        (7591351660, 1742515200),
        (7708562823, 1746835200),
        (7817256746, 1750204800),
        (7834356221, 1756684800),
        (7912577935, 1757894400),
        (8017192943, 1759622400),
        (8117852491, 1760400000),
        (8209194945, 1761436800),
        (8480708838, 1762300800),
        (8559682245, 1762819200)
    ]

    private static let russianMonths = [
        "янв.", "фев.", "мар.", "апр.", "мая", "июн.",
        "июл.", "авг.", "сен.", "окт.", "нояб.", "дек."
    ]

    public static func estimate(userId: Int64) -> String? {
        guard userId > 0 else {
            return nil
        }
        guard let first = milestones.first, let last = milestones.last else {
            return nil
        }

        let estimatedTimestamp: Int64
        if userId <= first.userId {
            estimatedTimestamp = first.timestamp
        } else if userId >= last.userId {
            let ratio = Double(userId - last.userId) / Double(800_000_000)
            let extraSeconds = Int64(ratio * 365.25 * 86400.0)
            estimatedTimestamp = min(last.timestamp + extraSeconds, Int64(Date().timeIntervalSince1970))
        } else {
            var lower = first
            var upper = last
            for i in 0 ..< (milestones.count - 1) {
                let m1 = milestones[i]
                let m2 = milestones[i + 1]
                if m1.userId <= userId && userId <= m2.userId {
                    lower = m1
                    upper = m2
                    break
                }
            }
            let range = Double(upper.userId - lower.userId)
            let factor = range > 0.0 ? Double(userId - lower.userId) / range : 0.0
            estimatedTimestamp = lower.timestamp + Int64(factor * Double(upper.timestamp - lower.timestamp))
        }

        let date = Date(timeIntervalSince1970: TimeInterval(estimatedTimestamp))
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0) ?? .current, from: date)
        guard let year = comps.year, let month = comps.month, month >= 1 && month <= 12 else {
            return nil
        }

        let monthName = russianMonths[month - 1]
        return "\(monthName) \(year) г."
    }
}
