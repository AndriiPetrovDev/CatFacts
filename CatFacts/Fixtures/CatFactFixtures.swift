#if DEBUG
    import Foundation

    enum CatFactFixtures {
        static func make(
            id: String = "fixture-fact",
            text: String = "A cat's whiskers help it sense nearby objects and navigate narrow spaces, even in the dark.",
            createdAt: Date = Date(),
            isVerified: Bool = true
        ) -> CatFact {
            CatFact(id: id, text: text, createdAt: createdAt, isVerified: isVerified)
        }

        static var list: [CatFact] {
            [
                make(
                    id: "fixture-1",
                    text: "Cats spend much of their day sleeping and grooming their fur."
                ),
                make(
                    id: "fixture-2",
                    createdAt: Date(timeIntervalSince1970: 0),
                    isVerified: false
                )
            ]
        }
    }
#endif
