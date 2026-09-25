<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc"
  xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>buildings</Name>
    <UserStyle>
      <Title>Buildings</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>buildings</Name>
          <MaxScaleDenominator>35000</MaxScaleDenominator>
          <PolygonSymbolizer>
            <Fill><CssParameter name="fill">#d9d0c9</CssParameter><CssParameter name="fill-opacity">1</CssParameter></Fill>
            <Stroke><CssParameter name="stroke">#b9a99c</CssParameter><CssParameter name="stroke-width">0.5</CssParameter></Stroke>
          </PolygonSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
