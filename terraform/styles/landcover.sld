<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc"
  xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>landcover</Name>
    <UserStyle>
      <Title>Land cover</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>large</Name>
          <ogc:Filter><ogc:PropertyIsGreaterThan><ogc:PropertyName>area</ogc:PropertyName><ogc:Literal>50000000</ogc:Literal></ogc:PropertyIsGreaterThan></ogc:Filter>
          <MinScaleDenominator>2000000</MinScaleDenominator>
          <PolygonSymbolizer><Fill><CssParameter name="fill"><ogc:Function name="Recode"><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>forest</ogc:Literal><ogc:Literal>#add19e</ogc:Literal><ogc:Literal>farmland</ogc:Literal><ogc:Literal>#eef0d5</ogc:Literal><ogc:Literal>grass</ogc:Literal><ogc:Literal>#cdebb0</ogc:Literal><ogc:Literal>residential</ogc:Literal><ogc:Literal>#e0dfdf</ogc:Literal><ogc:Literal>industrial</ogc:Literal><ogc:Literal>#ebdbe8</ogc:Literal><ogc:Literal>commercial</ogc:Literal><ogc:Literal>#f2dad9</ogc:Literal><ogc:Literal>quarry</ogc:Literal><ogc:Literal>#c5c3c3</ogc:Literal><ogc:Literal>cemetery</ogc:Literal><ogc:Literal>#aacbaf</ogc:Literal><ogc:Literal>scrub</ogc:Literal><ogc:Literal>#c8d7ab</ogc:Literal><ogc:Literal>heath</ogc:Literal><ogc:Literal>#d6d99f</ogc:Literal><ogc:Literal>wetland</ogc:Literal><ogc:Literal>#d6e5e0</ogc:Literal><ogc:Literal>rock</ogc:Literal><ogc:Literal>#dcd6cf</ogc:Literal><ogc:Literal>glacier</ogc:Literal><ogc:Literal>#ddecec</ogc:Literal><ogc:Literal>sand</ogc:Literal><ogc:Literal>#f5e9c6</ogc:Literal></ogc:Function></CssParameter></Fill></PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>medium</Name>
          <ogc:Filter><ogc:PropertyIsGreaterThan><ogc:PropertyName>area</ogc:PropertyName><ogc:Literal>1000000</ogc:Literal></ogc:PropertyIsGreaterThan></ogc:Filter>
          <MinScaleDenominator>250000</MinScaleDenominator>
          <MaxScaleDenominator>2000000</MaxScaleDenominator>
          <PolygonSymbolizer><Fill><CssParameter name="fill"><ogc:Function name="Recode"><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>forest</ogc:Literal><ogc:Literal>#add19e</ogc:Literal><ogc:Literal>farmland</ogc:Literal><ogc:Literal>#eef0d5</ogc:Literal><ogc:Literal>grass</ogc:Literal><ogc:Literal>#cdebb0</ogc:Literal><ogc:Literal>residential</ogc:Literal><ogc:Literal>#e0dfdf</ogc:Literal><ogc:Literal>industrial</ogc:Literal><ogc:Literal>#ebdbe8</ogc:Literal><ogc:Literal>commercial</ogc:Literal><ogc:Literal>#f2dad9</ogc:Literal><ogc:Literal>quarry</ogc:Literal><ogc:Literal>#c5c3c3</ogc:Literal><ogc:Literal>cemetery</ogc:Literal><ogc:Literal>#aacbaf</ogc:Literal><ogc:Literal>scrub</ogc:Literal><ogc:Literal>#c8d7ab</ogc:Literal><ogc:Literal>heath</ogc:Literal><ogc:Literal>#d6d99f</ogc:Literal><ogc:Literal>wetland</ogc:Literal><ogc:Literal>#d6e5e0</ogc:Literal><ogc:Literal>rock</ogc:Literal><ogc:Literal>#dcd6cf</ogc:Literal><ogc:Literal>glacier</ogc:Literal><ogc:Literal>#ddecec</ogc:Literal><ogc:Literal>sand</ogc:Literal><ogc:Literal>#f5e9c6</ogc:Literal></ogc:Function></CssParameter></Fill></PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>all</Name>
          <MaxScaleDenominator>250000</MaxScaleDenominator>
          <PolygonSymbolizer><Fill><CssParameter name="fill"><ogc:Function name="Recode"><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>forest</ogc:Literal><ogc:Literal>#add19e</ogc:Literal><ogc:Literal>farmland</ogc:Literal><ogc:Literal>#eef0d5</ogc:Literal><ogc:Literal>grass</ogc:Literal><ogc:Literal>#cdebb0</ogc:Literal><ogc:Literal>residential</ogc:Literal><ogc:Literal>#e0dfdf</ogc:Literal><ogc:Literal>industrial</ogc:Literal><ogc:Literal>#ebdbe8</ogc:Literal><ogc:Literal>commercial</ogc:Literal><ogc:Literal>#f2dad9</ogc:Literal><ogc:Literal>quarry</ogc:Literal><ogc:Literal>#c5c3c3</ogc:Literal><ogc:Literal>cemetery</ogc:Literal><ogc:Literal>#aacbaf</ogc:Literal><ogc:Literal>scrub</ogc:Literal><ogc:Literal>#c8d7ab</ogc:Literal><ogc:Literal>heath</ogc:Literal><ogc:Literal>#d6d99f</ogc:Literal><ogc:Literal>wetland</ogc:Literal><ogc:Literal>#d6e5e0</ogc:Literal><ogc:Literal>rock</ogc:Literal><ogc:Literal>#dcd6cf</ogc:Literal><ogc:Literal>glacier</ogc:Literal><ogc:Literal>#ddecec</ogc:Literal><ogc:Literal>sand</ogc:Literal><ogc:Literal>#f5e9c6</ogc:Literal></ogc:Function></CssParameter></Fill></PolygonSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
