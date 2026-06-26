// class CertificateModel {
//   final String headerImagePath;
//   final String certificateType;
//   final String jobNumber;
//   final List<Map<String, String>> defaultRecommendations;
//   final List<Map<String, String>> cargoDetails;
//   final String projectTitle;
//   final String certificateNumber;
//   final String clientName;
//   final String cargo;
//   final String departurePort;
//   final String arrivalPort;
//   final String? issuedDate; // Use ISO string
//   final bool noDateCheckbox;
//   final String surveyedBy;
//   final String reviewedBy;
//   final String towName;
//   final String tugName;
//   final String? stampPath;
//   final String? signaturePath;
//   final String? signatureClient;
//   final bool isCargoDetailsNA;
//   final bool includeAnnexure2;
//   final bool includeCargoDetails;

//   CertificateModel({
//     required this.headerImagePath,
//     required this.certificateType,
//     required this.jobNumber,
//     required this.defaultRecommendations,
//     required this.cargoDetails,
//     required this.projectTitle,
//     required this.certificateNumber,
//     required this.clientName,
//     required this.cargo,
//     required this.departurePort,
//     required this.arrivalPort,
//     required this.issuedDate,
//     required this.noDateCheckbox,
//     required this.surveyedBy,
//     required this.reviewedBy,
//     required this.towName,
//     required this.tugName,
//     this.stampPath,
//     this.signaturePath,
//     this.signatureClient,
//     required this.isCargoDetailsNA,
//     required this.includeAnnexure2,
//     required this.includeCargoDetails,
//   });

//   Map<String, dynamic> toJson() => {
//     "HeaderImagePath": headerImagePath,
//     "CertificateType": certificateType,
//     "JobNumber": jobNumber,
//     "defaultRecommendations": defaultRecommendations,
//     "CargoDetails": cargoDetails,
//     "ProjectTitle": projectTitle,
//     "CertificateNumber": certificateNumber,
//     "ClientName": clientName,
//     "Cargo": cargo,
//     "DeparturePort": departurePort,
//     "ArrivalPort": arrivalPort,
//     "IssuedDate": issuedDate,
//     "NoDateCheckbox": noDateCheckbox,
//     "SurveyedBy": surveyedBy,
//     "ReviewedBy": reviewedBy,
//     "TowName": towName,
//     "TugName": tugName,
//     "StampPath": stampPath,
//     "SignaturePath": signaturePath,
//     "SignatureClient": signatureClient,
//     "IsCargoDetailsNA": isCargoDetailsNA,
//     "IncludeAnnexure2": includeAnnexure2,
//     "IncludeCargoDetails": includeCargoDetails,
//   };
// }
