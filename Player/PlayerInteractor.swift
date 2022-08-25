//
//  PlayerInteractor.swift
//
//  Created by jekster on 04.02.2021.
//

import Foundation

final class PlayerInteractor {
    
    fileprivate let apiService: APIService
    fileprivate let languageService: LanguageManager
    fileprivate let sportService: SportListMicroService
    fileprivate let tournamentService: TournamentMicroService
    fileprivate let countryListService: CountryListMicroService
    
    internal weak var delegate: PlayerModuleInteractorDelegate?
    
    private(set) var languageId: String
    
    init(
        apiService: APIService = DIContainer.default.apiService,
        languageService: LanguageManager = DIContainer.default.languageManager,
        sportService: SportListMicroService = DIContainer.default.sportListService,
        tournamentService: TournamentMicroService = DIContainer.default.tournamentService,
        countryListService: CountryListMicroService = DIContainer.default.countryListService
    ) {
        self.apiService = apiService
        self.languageService = languageService
        self.sportService = sportService
        self.tournamentService = tournamentService
        self.countryListService = countryListService
        self.languageId = self.languageService.currentLanguage.rawValue
    }
    
}

// MARK: - Extensions -

extension PlayerInteractor: PlayerModuleInteractor {
    
    func getCountryNameByTournament(id: Int) -> String? {
        guard let tournament = self.tournamentService.tournamentList.first(where: { $0.id == id}) else {
            return nil
        }
        guard let country = self.countryListService.countyList.first(where: { $0.id == tournament.country.id }) else {
            return nil
        }
        
        let item = LanguageItem(values: [
            Language.ru.rawValue: country.nameUkrainian,
            Language.en.rawValue: country.nameEnglish
        ], defaultLanguage: "ua")
        
        return item.getValue(language: self.languageId)
    }
    
    func getSportName(id: Int) -> String? {
        guard let sport = self.sportService.sportList.first(where: { $0.id == id }) else {
            return nil
        }
        
        return self.languageService.getLexic(for: sport.lexic)
    }
    
    func getMatchDetails(match: MatchItem) {
        self.apiService
            .getMatchInfo(
                id: match.id,
                sportType: match.sportType
            ) { [weak self] result in
                switch result {
                case .success(let response):
                    if response.live {
                        return
                    }
                    if response.hasVideo {
                        self?.fetchURL(match: match)
                        return
                    }
                    break
                case .failure(_):
                    break
                }
            }
    }
    
    private func fetchURL(match: MatchItem) {
        self.apiService
            .getMatchVideo(
                id: match.id,
                sportType: match.sportType
            ) { [weak self] (result) in
                switch result {
                case .success(let response):
                    let dict = Dictionary(grouping: response, by: { $0.quality })
                    
                    var result = [PlayerItem]()
                    
                    for key in dict.keys {
                        let items = (dict[key] ?? []).filter({ $0.abc_type == "tv"})
                        
                        var videos = items.map({ Playable(url: $0.url, period: $0.period, duration: $0.duration) })
                        videos.sort(by: { $0.period < $1.period })
                        result.append(PlayerItem(quality: key.toInt(), videos: videos))
                    }
                    
                    result.sort(by: { $0.quality > $1.quality })
                    
                    self?.delegate?.didPlayVideos(items: result)
                    
                case .failure(_):
                    break
                }
            }
    }
    
}
