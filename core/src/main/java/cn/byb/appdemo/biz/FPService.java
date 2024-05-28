package cn.byb.appdemo.biz;

import cn.fraudmetrix.forseti.fp.dubbo.DeviceInfoQuery;
import cn.fraudmetrix.forseti.fp.model.BaseResult;
import com.alibaba.fastjson.JSONObject;
import org.apache.dubbo.config.annotation.DubboReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.Map;

/**
 * @ClassName: FPService
 * @Description: fp对接调用业务
 * @Author: Waein
 * @Date: 2024/5/27 14:16
 **/
@Service
public class FPService {

    private static final Logger log = LoggerFactory.getLogger(FPService.class);
    @Value("${tiangong.fp.saas.blackbox}")
    private String blackbox;

    @Value("${tiangong.fp.saas.invoke.partnerCode}")
    private String partnerCode;

    @Resource
    private DeviceInfoQuery deviceInfoQuery;

    public String invoke() {
        BaseResult<Map<String, Object>> deviceInfoQ = deviceInfoQuery.query(blackbox, partnerCode);
        System.err.println(JSONObject.toJSONString(deviceInfoQ));
        return JSONObject.toJSONString(deviceInfoQ);
    }
}
