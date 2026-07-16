// **************************************************************************
// Class for HTTP API interaction of my.plantnet.org
// **************************************************************************
// MIT License
// Copyright © 2022 Patrick Fial
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
// associated documentation files (the “Software”), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute,
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions: The above copyright notice and this
// permission notice shall be included in all copies or substantial portions of the Software. THE
// SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
// LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// **************************************************************************
// includes
// **************************************************************************

#include "identification.hpp"

#include <QDebug>
#include <QFile>
#include <QHttpMultiPart>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QSettings>
#include <QUrlQuery>

#include <variant>

#define API_MAX_RESULTS 5
#define API_URL "https://my-api.plantnet.org/v2/identify/all"
#define LANGUAGES_URL "https://my-api.plantnet.org/v2/languages"
// #define API_URL "http://10.0.60.43:3000/identify"
// #define LANGUAGES_URL "http://10.0.60.43:3000/languages"

#define API_KEY_SETTING "apiKeyEnc"
#define API_KEY_SETTING_LEGACY "apiKey"

namespace C
{
#include <libintl.h>
}

namespace
{
// Not real encryption - just enough that the API key doesn't sit as plain,
// grep-able text in the app's ~/.config/plants.s710/*.conf file. Anyone with
// access to the app's binary can still recover the pad and reverse this; it
// only raises the bar against casually browsing the config file.
const char OBFUSCATION_PAD[] = "pl@ntnet-ut-plants-key-pad-2026";

QString obfuscateApiKey(const QString& plain)
{
   QByteArray data = plain.toUtf8();
   QByteArray pad(OBFUSCATION_PAD);

   for (int i = 0; i < data.size(); ++i)
      data[i] = data[i] ^ pad[i % pad.size()];

   return QString::fromLatin1(data.toBase64());
}

QString deobfuscateApiKey(const QString& encoded)
{
   QByteArray data = QByteArray::fromBase64(encoded.toLatin1());
   QByteArray pad(OBFUSCATION_PAD);

   for (int i = 0; i < data.size(); ++i)
      data[i] = data[i] ^ pad[i % pad.size()];

   return QString::fromUtf8(data);
}
} // namespace

namespace plants
{
// **************************************************************************
// class Identification
// **************************************************************************

Identification::Identification(network::Network* network, QObject* parent)
  : net(network),
    QObject(parent),
    url(API_URL)
{
   QString key = loadApiKey();

   if (!key.isEmpty())
      query.addQueryItem("api-key", key);

   query.addQueryItem("include-related-images", "true");
   url.setQuery(query);
}

// **************************************************************************
// identifyPlant
// **************************************************************************

void Identification::initLanguages()
{
   QSettings settings;
   QUrlQuery q;
   QString key = loadApiKey();

   if (key.isEmpty())
   {
      qDebug() << "No API key available, skip languages load";
      return;
   }

   q.addQueryItem("api-key", key);

   QUrl languagesUrl(LANGUAGES_URL);
   languagesUrl.setQuery(q);

   net->get<network::ReqCallback>(
     languagesUrl, headers,
     [this](int err, int code, QByteArray body)
     {
        QSettings settings;

        if (err != QNetworkReply::NoError || code != 200 || body.isEmpty())
        {
           qDebug() << "FAIL Languages response: " << QString::number(code) << " (" << body << ")";

           QString lang("en");

           if (settings.contains("language"))
              lang = settings.value("language").toString();

           query.addQueryItem("lang", lang);
           url.setQuery(query);
           return;
        }

        QString systemLang = QLocale::system().name().split('_').at(0);

        auto doc = QJsonDocument::fromJson(body);
        auto parsed = (!doc.isNull() && doc.isArray()) ? doc.array() : QJsonArray();

        QStringList languages;

        foreach (auto lang, parsed)
           languages << lang.toString();

        if (languages.contains(systemLang))
        {
           query.addQueryItem("lang", systemLang);
           url.setQuery(query);
           settings.setValue("language", systemLang);
        }
        else
        {
           query.addQueryItem("lang", "en");
           url.setQuery(query);
           settings.setValue("language", "en");
        }
     });
}

// **************************************************************************
// setApiKey
// **************************************************************************

void Identification::setApiKey(QString key)
{
   query.removeQueryItem("api-key");
   query.addQueryItem("api-key", key);
   url.setQuery(query);
}

// **************************************************************************
// persistApiKey
// **************************************************************************

void Identification::persistApiKey(QString key)
{
   QSettings settings;

   settings.setValue(API_KEY_SETTING, obfuscateApiKey(key));
   settings.remove(API_KEY_SETTING_LEGACY);
   settings.sync();

   setApiKey(key);
}

// **************************************************************************
// loadApiKey
// **************************************************************************

QString Identification::loadApiKey()
{
   QSettings settings;

   if (settings.contains(API_KEY_SETTING))
      return deobfuscateApiKey(settings.value(API_KEY_SETTING).toString());

   // migrate a plaintext key saved by an older version of the app
   if (settings.contains(API_KEY_SETTING_LEGACY))
   {
      QString legacyKey = settings.value(API_KEY_SETTING_LEGACY).toString();

      settings.setValue(API_KEY_SETTING, obfuscateApiKey(legacyKey));
      settings.remove(API_KEY_SETTING_LEGACY);
      settings.sync();

      return legacyKey;
   }

   return "";
}

// **************************************************************************
// hasApiKey
// **************************************************************************

bool Identification::hasApiKey()
{
   return !loadApiKey().isEmpty();
}

// **************************************************************************
// testApiKey
// **************************************************************************

void Identification::testApiKey(QString key)
{
   QUrlQuery q;
   q.addQueryItem("api-key", key);

   QUrl testUrl(LANGUAGES_URL);
   testUrl.setQuery(q);

   net->get<network::ReqCallback>(
     testUrl, headers,
     [this](int err, int code, QByteArray /*body*/)
     {
        if (err != QNetworkReply::NoError || code != 200)
        {
           QString message;

           if (code == 401 || code == 403)
              message = C::gettext("Invalid API key");
           else if (err != QNetworkReply::NoError)
              message = C::gettext("Network error, please check your connection");
           else
              message = QString(C::gettext("Unexpected server response (%1)")).arg(code);

           emit apiKeyTestResult(false, message);
           return;
        }

        emit apiKeyTestResult(true, "");
     });
}

// **************************************************************************
// identifyPlant
// **************************************************************************

void Identification::identifyPlant(QVariantList& request)
{
   QString err;
   QVariantList sourceImages;
   QHttpMultiPart* multiPart = createMultipart(request, sourceImages, err);

   if (multiPart == nullptr)
   {
      emit identificationResult(QString(err), QVariantList());
      return;
   }

   net->postMultipart<network::ReqCallback>(
     url, multiPart, headers,
     [this, multiPart, sourceImages](int err, int code, QByteArray body)
     {
        QVariantList resultPayload;
        delete multiPart;

        qDebug() << "Identify response: " << QString::number(code);

        if (err != QNetworkReply::NoError || code != 200 || body.isEmpty())
        {
           qDebug() << "Identify response: " << QString::number(code) << " (" << body << ")";
           emit identificationResult(
             QString(C::gettext("Failed to process identification (%1/%2)")).arg(err).arg(code),
             resultPayload);
           return;
        }

        auto doc = QJsonDocument::fromJson(body);
        auto parsed = (!doc.isNull() && doc.isObject()) ? doc.object() : QJsonObject();

        if (parsed.isEmpty() || !parsed.contains("results"))
        {
           emit identificationResult(QString(C::gettext("Unexpected/malformed response received")),
                                     resultPayload);
           return;
        }

        foreach (auto result, parsed["results"].toArray())
        {
           if (resultPayload.size() >= API_MAX_RESULTS)
              break;

           QVariantMap currentResult;
           QVariantList currentImages;
           auto dict = result.toObject();

           if (!dict.contains("score") || !dict.contains("species") || !dict.contains("images"))
           {
              qDebug() << "Skipping invalid result: missing score/species/images";
              continue;
           }

           currentResult["score"] = dict["score"].toDouble();

           auto species = dict["species"].toObject();

           if (!species.contains("scientificName") || !species.contains("commonNames"))
           {
              qDebug() << "Skipping invalid result: missing scientificName/commonNames";
              continue;
           }

           currentResult["species"] = species["scientificName"].toString();

           QStringList commonNames;

           foreach (auto commonName, species["commonNames"].toArray())
           {
              commonNames << commonName.toString();
           }

           currentResult["commonNames"] = commonNames.join(", ");

           foreach (auto image, dict["images"].toArray())
           {
              QVariantMap currentImage;

              auto dict = image.toObject();

              if (!dict.contains("url") || !dict.contains("citation")
                  || !dict["url"].toObject().contains("m"))
              {
                 qDebug() << "Skipping invalid result image: missing url/citation";
                 continue;
              }

              currentImage["url"] = dict["url"].toObject()["m"].toString();
              currentImage["copyright"] = dict["citation"].toString();

              currentImages << currentImage;
           }

           currentResult["images"] = currentImages;
           currentResult["sourceImages"] = sourceImages;
           resultPayload << currentResult;
        }

        emit identificationResult("", resultPayload);
     });
}

// **************************************************************************
// createMultipart
// **************************************************************************

QHttpMultiPart* Identification::createMultipart(QVariantList& request, QVariantList& sourceUrls,
                                                QString& err)
{
   QHttpMultiPart* multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

   if (!request.size())
   {
      err = "No images contained in request";
      delete multiPart;
      return nullptr;
   }

   for (QVariant& imageInfo : request)
   {
      QVariantMap map = imageInfo.toMap();

      if (!map.contains("url") || !map.contains("organ"))
      {
         err = "Invalid image info with missing url/type";
         delete multiPart;
         return nullptr;
      }

      QString url = map["url"].toString();
      QString organ = map["organ"].toString();

      sourceUrls << url;

      QHttpPart textPart;
      textPart.setHeader(QNetworkRequest::ContentDispositionHeader,
                         QVariant("form-data; name=\"organs\""));
      textPart.setBody(organ.toUtf8());
      multiPart->append(textPart);

      QHttpPart imagePart;
      imagePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                          QVariant("form-data; name=\"images\"; filename=\"image_1.jpeg\""));
      imagePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("image/jpeg"));

      QFile* file = new QFile(url);
      file->setParent(multiPart); // we cannot delete the file now, so delete it with the multiPart

      if (!file->open(QIODevice::ReadOnly))
      {
         err = QString("Failed to open image file for upload: %1 (%2)").arg(url, file->errorString());
         delete multiPart;
         return nullptr;
      }

      imagePart.setBodyDevice(file);
      multiPart->append(imagePart);
   }

   return multiPart;
}
} // namespace plants