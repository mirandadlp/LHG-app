import Foundation
import Testing

@testable import LondonPropertyHub

/// A full record decoded from a payload shaped exactly as the API returns it.
struct PropertyDetailDecodingTests {

    private let json = """
    {
      "id": 1,
      "publicId": "6b1f0f2e-0000-4000-8000-000000000000",
      "verification": "In Progress",
      "submittedAt": null,
      "verifiedAt": null,
      "verificationDueOn": null,
      "values": {
        "siteName": "Croydon Housing",
        "addressLine1": "142 London Road",
        "city": "Croydon",
        "postcode": "CR0 2TB",
        "borough": "Croydon",
        "manager": "Jane Smith",
        "floors": 7,
        "avgBedroom": { "v": 12.6, "u": "m²" },
        "stepFree": "Yes",
        "generalNotes": null
      },
      "accommodation": { "singles": 105, "doubles": 72, "house5": null },
      "totalUnits": 339,
      "flatsTotal": 73,
      "housesTotal": 4,
      "elevators": [
        {
          "id": 1, "name": "Lift A", "type": "Passenger", "capacity": 8,
          "maxOccupancy": 8, "width": 1.1, "depth": 1.4, "height": 2.2,
          "doorWidth": 0.9, "accessible": "Yes", "service": "No",
          "passenger": "Yes", "notes": "Serves floors G-7.", "position": 0
        }
      ],
      "staircases": [
        {
          "id": 1, "name": "Stair 1", "location": "North core", "floorsServed": 8,
          "width": 1.2, "classification": "Emergency", "emergencyExit": "Yes",
          "notes": "", "position": 0
        }
      ],
      "documents": [
        {
          "id": 1, "name": "Floorplans.pdf", "type": "Floor Plan",
          "date": "2026-06-02", "by": "Jane Smith", "notes": "",
          "sizeBytes": 20480, "mimeType": "application/pdf",
          "downloadUrl": "https://api.example/api/documents/1/download"
        }
      ],
      "history": [
        {
          "id": 1, "field": "Singles", "prev": "98", "next": "105",
          "by": "Jane Smith", "date": "2026-08-12 09:41",
          "reason": "Property manager verification", "approval": "Pending"
        }
      ],
      "flags": [
        {
          "id": 1, "key": "triples", "label": "Triples", "prev": 38, "next": 4,
          "resolution": "Pending", "raisedAt": "2026-08-12T09:41:00+00:00"
        }
      ],
      "completeness": 91,
      "missing": {
        "required": [{ "key": "council", "label": "Council", "section": "general" }],
        "optional": []
      },
      "pendingApprovalCount": 2,
      "permissions": {
        "canEdit": true, "canSubmit": true, "canReview": false, "canDelete": false
      },
      "createdAt": "2026-01-01T00:00:00+00:00",
      "updatedAt": "2026-08-12T09:41:00+00:00"
    }
    """

    private func decoded() throws -> PropertyDetail {
        try JSONDecoder().decode(PropertyDetail.self, from: Data(json.utf8))
    }

    @Test("The whole record decodes")
    func decodesFully() throws {
        let detail = try decoded()

        #expect(detail.id == 1)
        #expect(detail.verification == .inProgress)
        #expect(detail.totalUnits == 339)
        #expect(detail.completeness == 91)
        #expect(detail.elevators.count == 1)
        #expect(detail.staircases.count == 1)
        #expect(detail.documents.count == 1)
        #expect(detail.history.count == 1)
        #expect(detail.flags.count == 1)
    }

    @Test("Convenience accessors read the value bag")
    func accessors() throws {
        let detail = try decoded()

        #expect(detail.siteName == "Croydon Housing")
        #expect(detail.managerLabel == "Jane Smith")
        #expect(detail.fullAddress == "142 London Road, Croydon, CR0 2TB")
        #expect(detail.values["floors"]?.intValue == 7)
        #expect(detail.values["stepFree"]?.triState == .yes)
        #expect(detail.values["avgBedroom"]?.measurementUnit == "m²")
    }

    @Test("A blank accommodation count reads as zero, never as unknown")
    func blankCountsAreZero() throws {
        let detail = try decoded()

        #expect(detail.count("singles") == 105)
        #expect(detail.count("house5") == 0)   // Present but null.
        #expect(detail.count("flat3") == 0)    // Absent entirely.
        #expect(detail.sum(of: ["singles", "doubles", "house5"]) == 177)
    }

    @Test("A missing site name falls back rather than showing empty")
    func untitledFallback() throws {
        var detail = try decoded()
        detail.values["siteName"] = .empty

        #expect(detail.siteName == "Untitled property")
    }

    @Test("Permissions drive what the screen offers")
    func permissions() throws {
        let detail = try decoded()

        #expect(detail.permissions.canEdit)
        #expect(detail.permissions.canReview == false)
        #expect(detail.missing.required.first?.label == "Council")
    }
}
