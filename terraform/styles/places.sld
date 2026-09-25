<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc"
  xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>places</Name>
    <UserStyle>
      <Title>Places</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>city</Name>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>city</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <MaxScaleDenominator>10000000</MaxScaleDenominator>
          <PointSymbolizer><Graphic><Mark><WellKnownName>circle</WellKnownName><Fill><CssParameter name="fill">#333333</CssParameter></Fill><Stroke><CssParameter name="stroke">#ffffff</CssParameter><CssParameter name="stroke-width">0.5</CssParameter></Stroke></Mark><Size>6</Size></Graphic></PointSymbolizer>
          <TextSymbolizer><Label><ogc:PropertyName>name</ogc:PropertyName></Label><Font><CssParameter name="font-family">DejaVu Sans</CssParameter><CssParameter name="font-size">13</CssParameter><CssParameter name="font-weight">bold</CssParameter></Font><Halo><Radius>1.5</Radius><Fill><CssParameter name="fill">#ffffff</CssParameter></Fill></Halo><Fill><CssParameter name="fill">#333333</CssParameter></Fill></TextSymbolizer>
        </Rule>
        <Rule>
          <Name>town</Name>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>town</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <MaxScaleDenominator>2000000</MaxScaleDenominator>
          <PointSymbolizer><Graphic><Mark><WellKnownName>circle</WellKnownName><Fill><CssParameter name="fill">#555555</CssParameter></Fill><Stroke><CssParameter name="stroke">#ffffff</CssParameter><CssParameter name="stroke-width">0.5</CssParameter></Stroke></Mark><Size>4</Size></Graphic></PointSymbolizer>
          <TextSymbolizer><Label><ogc:PropertyName>name</ogc:PropertyName></Label><Font><CssParameter name="font-family">DejaVu Sans</CssParameter><CssParameter name="font-size">11</CssParameter><CssParameter name="font-weight">normal</CssParameter></Font><Halo><Radius>1.5</Radius><Fill><CssParameter name="fill">#ffffff</CssParameter></Fill></Halo><Fill><CssParameter name="fill">#333333</CssParameter></Fill></TextSymbolizer>
        </Rule>
        <Rule>
          <Name>village</Name>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>village</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <MaxScaleDenominator>250000</MaxScaleDenominator>
          <TextSymbolizer><Label><ogc:PropertyName>name</ogc:PropertyName></Label><Font><CssParameter name="font-family">DejaVu Sans</CssParameter><CssParameter name="font-size">10</CssParameter><CssParameter name="font-weight">normal</CssParameter></Font><Halo><Radius>1.5</Radius><Fill><CssParameter name="fill">#ffffff</CssParameter></Fill></Halo><Fill><CssParameter name="fill">#333333</CssParameter></Fill></TextSymbolizer>
        </Rule>
        <Rule>
          <Name>small</Name>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>hamlet</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>suburb</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <MaxScaleDenominator>70000</MaxScaleDenominator>
          <TextSymbolizer><Label><ogc:PropertyName>name</ogc:PropertyName></Label><Font><CssParameter name="font-family">DejaVu Sans</CssParameter><CssParameter name="font-size">9</CssParameter><CssParameter name="font-weight">normal</CssParameter></Font><Halo><Radius>1.5</Radius><Fill><CssParameter name="fill">#ffffff</CssParameter></Fill></Halo><Fill><CssParameter name="fill">#333333</CssParameter></Fill></TextSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
