import Foundation
import CoreLocation
import WeatherKit

/// WeatherKit 日出日落与天气数据提供者
final class WeatherProvider: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    /// 拉取节律输入
    func fetch(now: Date) async -> CircadianInputs {
        // 1. 请求定位
        let coordinate = await requestLocation()
        
        guard let coord = coordinate else {
            // 无定位 → 降级 L0
            return CircadianInputs(
                availability: .estimated,
                location: nil
            )
        }
        
        // 2. 获取天气数据
        do {
            let weather = try await WeatherService.shared.weather(
                for: CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            )
            
            let dailyForecast = weather.dailyForecast.first
            let currentWeather = weather.currentWeather
            
            let sunrise = dailyForecast?.sun.sunrise
            let sunset = dailyForecast?.sun.sunset
            
            var daylightDuration: TimeInterval?
            if let sr = sunrise, let ss = sunset {
                daylightDuration = ss.timeIntervalSince(sr)
            }
            
            return CircadianInputs(
                availability: .measured,
                location: coord,
                sunrise: sunrise,
                sunset: sunset,
                daylightDuration: daylightDuration,
                cloudCover: currentWeather.cloudCover,
                uvIndex: Double(currentWeather.uvIndex.value),
                condition: currentWeather.condition.description,
                moonPhase: nil  // MoonPhase enum不直接转 Double，POC 暂不使用
            )
        } catch {
            print("WeatherProvider error: \(error)")
            return CircadianInputs(
                availability: .estimated,
                location: coord
            )
        }
    }
    
    // MARK: - Location
    
    private func requestLocation() async -> CLLocationCoordinate2D? {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // 等一下权限结果后再请求
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let newStatus = locationManager.authorizationStatus
            guard newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways else {
                return nil
            }
        case .denied, .restricted:
            return nil
        default:
            break
        }
        
        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.first?.coordinate)
        locationContinuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}
