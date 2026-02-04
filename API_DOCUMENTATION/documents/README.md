# Documents API Documentation

## Overview

The Documents API in Wanzo provides endpoints for managing documents such as uploading, retrieving, and deleting files related to various entities in the system (invoices, expenses, customers, etc.). It supports multipart file uploads and associating documents with specific business entities.

## Models

### Document Model

The `Document` model represents a document in the system with the following properties:

```json
{
  "id": "string",
  "title": "string",
  "description": "string (optional)",
  "type": "string (optional)",
  "fileType": "string (optional)",
  "filePath": "string",
  "creationDate": "datetime",
  "userId": "string (optional)",
  "relatedEntityId": "string (optional)",
  "relatedEntityType": "string (optional)",
  "fileSize": "number (optional)"
}
```

### Mapping des Champs (API ↔ Application)

Le modèle de l'application utilise des noms de champs différents de l'API pour plus de clarté:

| API (Backend) | Application (Frontend) | Description |
|---------------|------------------------|-------------|
| `fileName` | `title` | Nom ou titre du document |
| `url` | `filePath` | Chemin/URL du document |
| `uploadedAt` | `creationDate` | Date de création/upload |
| `entityId` | `relatedEntityId` | ID de l'entité associée |
| `entityType` | `relatedEntityType` | Type de l'entité associée |

### Description des Champs

- **`id`**: Identifiant unique du document
- **`title`**: Titre ou nom du document (correspond à `fileName` dans l'API)
- **`description`**: Description optionnelle du document (champ local uniquement)
- **`type`**: Type de document (voir types ci-dessous)
- **`fileType`**: Type MIME ou extension (pdf, jpg, png, etc.)
- **`filePath`**: Chemin local ou URL Cloudinary du fichier (correspond à `url` dans l'API)
- **`creationDate`**: Date de création/upload du document (correspond à `uploadedAt` dans l'API)
- **`userId`**: ID de l'utilisateur qui a créé le document
- **`relatedEntityId`**: ID de l'entité liée (facture, dépense, client, etc.) (correspond à `entityId` dans l'API)
- **`relatedEntityType`**: Type de l'entité liée (correspond à `entityType` dans l'API)
- **`fileSize`**: Taille du fichier en octets

### Types de Documents

L'enum `DocumentType` définit les types de documents supportés:

- `invoice` - Facture
- `receipt` - Reçu
- `quote` - Devis
- `contract` - Contrat
- `report` - Rapport
- `other` - Autre

**Exemple**:
```json
{
  "id": "doc_123",
  "title": "Facture Mars 2024",
  "description": "Facture mensuelle pour services rendus",
  "type": "invoice",
  "fileType": "pdf",
  "filePath": "https://res.cloudinary.com/wanzo/invoice_march.pdf",
  "creationDate": "2024-03-15T10:30:00.000Z",
  "relatedEntityId": "sale_456",
  "relatedEntityType": "sale",
  "fileSize": 245760
}
```

### Gestion Offline des Documents

Comme pour les autres entités, les documents supportent le mode offline:

1. **Mode Offline**: 
   - `filePath` contient le chemin local du fichier
   - Document stocké dans le stockage local de l'appareil

2. **Synchronisation**:
   - Upload automatique vers Cloudinary lors de la connexion
   - `filePath` mis à jour avec l'URL Cloudinary
   - Backend enregistre le document avec l'URL publique

3. **Compatibilité**: 
   - Les deux formats (chemin local et URL) sont supportés
   - L'app détecte automatiquement le type et affiche correctement

## API Endpoints

### Upload Document

Uploads a new document file and associates it with an entity.

- **Endpoint**: `/documents/upload`
- **Method**: POST
- **Content-Type**: `multipart/form-data`
- **Authorization**: Bearer token required
- **Form Parameters**:
  - `documentFile`: The file to upload (required)
  - `entityId`: ID of the entity to associate with (required)
  - `entityType`: Type of the entity (required)
- **Response**:
  ```json
  {
    "success": true,
    "data": Document,
    "message": "Document uploaded successfully.",
    "statusCode": 200
  }
  ```

### Get Documents

Retrieves a list of documents, with optional filtering.

- **Endpoint**: `/documents`
- **Method**: GET
- **Authorization**: Bearer token required
- **Query Parameters**:
  - `entityId`: Filter by entity ID (optional)
  - `entityType`: Filter by entity type (optional)
  - `documentType`: Filter by document type (optional)
  - `page`: Page number for pagination (optional)
  - `limit`: Number of items per page (optional)
- **Response**:
  ```json
  {
    "success": true,
    "data": [Document],
    "message": "Documents fetched successfully.",
    "statusCode": 200
  }
  ```

### Get Document by ID

Retrieves a specific document by its ID.

- **Endpoint**: `/documents/{id}`
- **Method**: GET
- **Authorization**: Bearer token required
- **URL Parameters**:
  - `id`: ID of the document to retrieve
- **Response**:
  ```json
  {
    "success": true,
    "data": Document,
    "message": "Document fetched successfully.",
    "statusCode": 200
  }
  ```

### Delete Document

Deletes a specific document.

- **Endpoint**: `/documents/{id}`
- **Method**: DELETE
- **Authorization**: Bearer token required
- **URL Parameters**:
  - `id`: ID of the document to delete
- **Response**:
  ```json
  {
    "success": true,
    "data": null,
    "message": "Document deleted successfully.",
    "statusCode": 200
  }
  ```

## Usage Example

```dart
// Upload a document
final File file = File('/path/to/file.pdf');
final ApiResponse<Document> uploadResponse = await documentApiService.uploadDocument(
  file: file,
  entityId: 'invoice-123',
  entityType: 'invoice',
);

// Get documents filtered by entity
final ApiResponse<List<Document>> documents = await documentApiService.getDocuments(
  entityId: 'invoice-123',
  entityType: 'invoice',
  page: 1,
  limit: 10,
);

// Get a specific document
final ApiResponse<Document> document = await documentApiService.getDocumentById('document-id');

// Delete a document
final ApiResponse<void> deleteResponse = await documentApiService.deleteDocument('document-id');
```

## Error Handling

The Documents API handles errors in several ways:

1. Validates file uploads and returns appropriate error messages for invalid files
2. Uses standard HTTP status codes to indicate success or failure
3. Returns detailed error messages in the API response
4. Handles multipart form data errors specifically for file uploads

## Implementation Notes

1. The API supports any file type, but the application may restrict certain file types for security
2. Files are stored on a secure server and accessed via signed URLs
3. The system may impose file size limits (not explicitly defined in the API)
4. Documents are associated with entities to maintain proper organization
5. Document deletion is permanent and cannot be undone
